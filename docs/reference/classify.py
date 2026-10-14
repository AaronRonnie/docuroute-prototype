# DocuRoute "small AI" -- document type classifier, v0.
#
# Reality check on the data: we have exactly ONE real example of each of the
# 3 in-scope document types (Prerequisite Waiver / Section Adjustment /
# Clearance) -- the blank Mapua templates, no filled/photographed submissions
# exist yet. A parametric classifier (logistic regression etc.) trained on
# n=1 per class would just memorize that one example and tell us nothing.
#
# So instead this is a ONE-SHOT / template-matching classifier: TF-IDF
# vectorize every document (including the 115 unrelated "other" Mapua forms
# we scanned as a real negative set), then classify new text by cosine
# similarity to each of the 3 reference templates. Confidence = how similar
# the closest match is. This is a legitimate, standard approach for exactly
# this situation (one canonical example per class), and it upgrades cleanly
# later: once real filled/photographed submissions exist, average multiple
# examples per class into a richer prototype, or swap in a trained model
# without changing anything downstream (this module's job is just
# classify(text) -> (type, confidence)).
import json
import sys
from pathlib import Path

import joblib
import numpy as np
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.metrics.pairwise import cosine_similarity

sys.stdout.reconfigure(encoding="utf-8")

DATASET_PATH = Path(__file__).parent / "dataset.json"
MODEL_PATH = Path(__file__).parent / "model.joblib"

LABELS = ["waiver", "adjustment", "clearance", "course_completion", "crediting", "shift_program"]


def train():
    records = json.loads(DATASET_PATH.read_text(encoding="utf-8"))
    texts = [r["text"] for r in records]
    labels = [r["label"] for r in records]

    vectorizer = TfidfVectorizer(
        lowercase=True,
        ngram_range=(1, 2),
        min_df=1,
        stop_words="english",
    )
    matrix = vectorizer.fit_transform(texts)

    # Prototype for every label present in the dataset, not just the 3
    # in-scope types -- this includes "other", the average of the 113
    # unrelated Mapua forms already scanned. That gives the classifier a
    # genuine "this looks like some other Mapua form" competitor instead of
    # being forced to always pick one of our 3 types no matter how unrelated
    # the input actually is. LABELS (the 3 in-scope types) stays the only
    # thing DocuRoute is scoped to route -- "other" is purely an internal
    # rejection signal, not a new document type the app knows about.
    prototypes = {}
    for label in sorted(set(labels)):
        idxs = [i for i, l in enumerate(labels) if l == label]
        # Average every known example of this type into one prototype vector
        # (still just 1-2 examples for the 3 real types today, but this is
        # what lets each prototype get richer/more representative as real
        # examples are added later).
        prototypes[label] = np.asarray(matrix[idxs].mean(axis=0))

    joblib.dump({"vectorizer": vectorizer, "prototypes": prototypes}, MODEL_PATH)
    print(f"Trained on {len(texts)} documents ({sum(1 for l in labels if l != 'other')} labeled, "
          f"{sum(1 for l in labels if l == 'other')} 'other'). Saved to {MODEL_PATH}")
    return vectorizer, prototypes, records


def classify(text: str, vectorizer=None, prototypes=None):
    if vectorizer is None or prototypes is None:
        bundle = joblib.load(MODEL_PATH)
        vectorizer, prototypes = bundle["vectorizer"], bundle["prototypes"]
    vec = vectorizer.transform([text])
    sims = {label: float(cosine_similarity(vec, proto)[0][0]) for label, proto in prototypes.items()}
    overall_best = max(sims, key=sims.get)

    if overall_best not in LABELS:
        # Matches the "other" prototype (some unrelated Mapua form, or -- for
        # a non-form photo -- just noise) more than any of our 3 in-scope
        # types. Reject it rather than force-fitting it to whichever of the
        # 3 happened to score highest. The confidence returned is the best
        # in-scope candidate only, for logging/diagnostics -- it is not
        # eligible to clear the 70% gate, since it lost to "other".
        best_in_scope = max(LABELS, key=lambda l: sims.get(l, 0.0))
        confidence = round(sims.get(best_in_scope, 0.0) * 100)
        return None, confidence, sims

    confidence = round(sims[overall_best] * 100)
    return overall_best, confidence, sims


def validate(vectorizer, prototypes, records):
    """Real, honest check with the data we actually have: do the 113 unrelated
    Mapua forms get correctly kept OUT of our 3 types, and do the 3 known
    templates match themselves? This is legitimate today even with n=1-2 per
    real class -- it's testing specificity against real negative examples, not
    generalization within a class (that needs real filled submissions)."""
    correct_self_match = 0
    correctly_rejected_as_other = 0  # an "other" doc that explicitly lost to the "other" prototype
    false_positives = []  # an "other" doc that still scored high confidence on one of our 3 types
    for r in records:
        pred_label, conf, _ = classify(r["text"], vectorizer, prototypes)
        if r["label"] in LABELS:
            if pred_label == r["label"]:
                correct_self_match += 1
        elif r["label"] == "other":
            if pred_label is None:
                correctly_rejected_as_other += 1
            elif conf >= 70:
                false_positives.append((r["file"], pred_label, conf))

    total_labeled = sum(1 for r in records if r["label"] in LABELS)
    total_other = sum(1 for r in records if r["label"] == "other")
    print(f"\nSelf-match on known templates: {correct_self_match}/{total_labeled}")
    print(f"'Other' documents ({total_other}) explicitly recognized as a different kind of "
          f"Mapua form (matched the 'other' prototype, not one of our 3 types): "
          f"{correctly_rejected_as_other}/{total_other}")
    print(f"'Other' documents that would incorrectly clear the 70% gate as one of our 3 types: "
          f"{len(false_positives)}")
    for f, label, conf in false_positives[:15]:
        print(f"  - {Path(f).name} -> classified as {label} @ {conf}%")


if __name__ == "__main__":
    vectorizer, prototypes, records = train()
    validate(vectorizer, prototypes, records)

    print("\n--- Quick manual test: classifying each known template as if it were a fresh scan ---")
    for r in records:
        if r["label"] in LABELS:
            pred_label, conf, sims = classify(r["text"], vectorizer, prototypes)
            print(f"{Path(r['file']).name}: true={r['label']} pred={pred_label} conf={conf}%  all_sims={ {k: round(v,3) for k,v in sims.items()} }")
