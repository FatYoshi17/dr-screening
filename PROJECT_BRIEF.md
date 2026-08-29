# Diabetic Retinopathy (DR) Screening Pipeline — Project Brief

*A MATLAB/Simulink-based automated DR screening system for rural India deployment*

---

## 1. The Problem (Why This Exists)

India has 77+ million diabetic adults — second highest in the world. ~18% develop diabetic retinopathy (DR), a leading cause of preventable blindness. Early screening prevents 90% of vision loss, but India has only ~1 ophthalmologist per 100,000 rural population — manual screening at that scale is impossible.

Existing AI screening tools have three problems we need to fix:
- They're **black boxes** — no explanation for their decisions.
- They lack **clinical validation rigor** — numbers reported on convenient test sets, not real benchmarks.
- They **fail on portable fundus camera images** — real field conditions (bad lighting, blur, non-expert operators) break them.

**Our job:** build a pipeline that's accurate, explainable, robust to bad field images, and includes a plan for how it'd actually be deployed and staffed at scale (100,000+ patients/year, district-level).

---

## 2. Medical Background (No Prior Knowledge Needed)

**Diabetic Retinopathy:** high blood sugar damages tiny blood vessels in the retina (back of the eye) over time. Damage is invisible to the patient until it's advanced — this is why *screening*, not waiting for symptoms, matters.

**What we're detecting in a fundus photo (photo of the retina):**
| Structure | What it is |
|---|---|
| Optic disc | Bright circular landmark where the optic nerve enters the eye |
| Fovea/macula | Central vision-critical region — lesions near it are more dangerous |
| Blood vessels | Mapped so lesions aren't confused with normal vessel crossings |
| Microaneurysms (MAs) | Tiny balloon-outpouchings of capillaries — the **earliest** sign of DR, only a few pixels wide — **hardest thing to detect in this whole project** |
| Hemorrhages | Larger blood leaks — dark blots/flame shapes |
| Exudates | Yellowish lipid deposits from leaky vessels — easier to detect (bright, high contrast) |
| Neovascularization | Abnormal new fragile vessels — sign of advanced disease |

**Severity scale (International Clinical DR Scale, 0–4):**

| Level | Name | What's present |
|---|---|---|
| 0 | No DR | Nothing abnormal |
| 1 | Mild NPDR | Microaneurysms only |
| 2 | Moderate NPDR | More lesions, some hemorrhages |
| 3 | Severe NPDR | Extensive hemorrhages, no new vessels yet |
| 4 | Proliferative DR (PDR) | Neovascularization — sight-threatening |

**"Referable DR" = Level 2+.** This is the actual decision that matters clinically (needs a specialist vs. can be monitored) — our target metrics are about this binary decision.

**Sensitivity vs. Specificity (our target metrics):**
- **Sensitivity >90%**: of everyone who truly has referable DR, catch >90% of them (missing a case is the dangerous failure mode).
- **Specificity >85%**: of everyone who doesn't, correctly clear >85% (too many false alarms overload the few available ophthalmologists).

---

## 3. The Five Modules

### Module 1 — Image Quality Assessment & Enhancement
Score each image for focus/illumination/field-of-view. Enhance borderline images (CLAHE = adaptive contrast boost, illumination normalization, denoising). Reject ungradeable images with recapture feedback.
**Difficulty:** Low–Medium. **Tools:** Image Processing Toolbox.

### Module 2 — Structure Segmentation
Extract: optic disc/fovea (easy), vessels (medium), exudates (medium), hemorrhages/neovascularization (medium-high), **microaneurysms (hard — sub-pixel, highest false-positive risk)**.
**Difficulty:** Medium–High overall; MA detection is the single hardest sub-task in the project — expect partial results in our timeframe, and say so honestly.

### Module 3 — DR Severity Grading
CNN trained on labeled images, outputs Level 0–4, collapsed to referable/non-referable. This is the core clinical decision.
**Difficulty:** Medium. **Tools:** Deep Learning Toolbox (Deep Network Designer GUI available for those new to it).

### Module 4 — Explainability
Grad-CAM heatmaps (highlight which pixels drove the decision), calibrated confidence scores (raw model confidence is usually overconfident — needs correction), auto-generated annotated report. Target: ophthalmologist can validate a case in under 30 seconds.
**Difficulty:** Low–Medium — MATLAB has a built-in `gradCAM` function.

### Module 5 — Simulink Workflow Simulation
Model the screening program as a queue: images arrive → get processed → a subset queues for limited human reviewers. Used to figure out staffing/resource needs for 100,000+ patients/year.
**Difficulty:** Medium, but steepest *learning-curve* item — Simulink is visual block-diagram programming, a different paradigm from writing code. Use MathWorks' SimEvents tutorials specifically (discrete-event simulation), not generic Simulink control-systems tutorials.

---

## 4. Datasets

| Dataset | Contains | Used for |
|---|---|---|
| **APTOS 2019** (Kaggle) | ~3,662 images, image-level 0–4 grade | Train/validate Module 3 (grading CNN) |
| **IDRiD** | Indian population data; image-level grades **+ pixel-level segmentation masks** for MA/hemorrhage/exudate/optic disc | Train/validate Module 2 (segmentation) — small (~81 fully masked images), so expect to augment heavily |
| **DRIVE** | 40 images, manual vessel segmentation masks | Vessel segmentation benchmark — classic dataset, many existing reference implementations |
| **Messidor-2** | ~1,748 images, DR grades | **External validation only** — train on APTOS, test here, to get an honest generalization number (this is our real "validated against published benchmarks" claim) |

**Access note:** IDRiD (IEEE DataPort) and Messidor-2 (ADCIS license) both require registration/approval that can take a day+ — request access on day 1, don't wait.

---

## 5. Two-Week Plan (PPT + Basic Prototype)

| Days | Focus | Deliverable |
|---|---|---|
| 1–2 | Setup | MATLAB license confirmed (check campus-wide license first), datasets requested/downloaded, everyone's toolboxes verified |
| 3–5 | Module 1 + Module 2 (vessels, optic disc) | Quality scoring + enhancement working; vessel map + disc localization on sample images |
| 6–8 | Module 2 (exudates, basic MA) + Module 3 | Lesion masks (rough OK); CNN trained on APTOS, first accuracy numbers |
| 9–10 | Module 4 | Grad-CAM overlay + auto-report on a sample image |
| 11–12 | Module 5 | Basic Simulink queueing model — arrival rate → processing → review queue |
| 13 | Integration + validation | End-to-end run; one honest sensitivity/specificity number using Messidor-2 as external test |
| 14 | PPT + rehearsal | Final deck |

**Be honest in the PPT about scope:** solid on IQA, vessels, exudates, grading, Grad-CAM. Partial/prototype-level on microaneurysm detection and neovascularization. Simplified (not fully detailed) Simulink model. This honesty is itself part of demonstrating clinical rigor — judges trust a clear "current status vs. roadmap" slide more than inflated claims.

---

## 6. Novelty Ideas (What Makes Us Different)

**Tier 1 — build these:**
1. **Field-condition stress-testing:** deliberately degrade test images (blur, brightness, vignetting) to simulate a bad portable camera, then show how accuracy/confidence degrades. Directly answers the brief's own complaint about field robustness. Cheap to build — reuses Module 1 tools.
2. **Confidence-tiered triage → Simulink:** feed Module 4's confidence scores into the Module 5 queue so review time varies by case urgency instead of being flat. This is the one place the "AI" and "deployment system" halves of the project actually connect.
3. **Lesion-attention overlap score:** a number measuring what % of the Grad-CAM heatmap overlaps with actual segmented lesions — turns "explainable" into a metric, not just a picture.

**Tier 2 — mention as design thinking, build partially if time allows:**
4. **Lite/full tiered pipeline:** a fast/cheap path for basic screening vs. a detailed path for flagged cases — matches the brief's mention of bandwidth/throughput constraints. Present as architecture, not two fully built models.
5. **Hybrid disagreement flagging:** run an interpretable rule-based classifier (from Module 2 counts) alongside the CNN; when they disagree, flag for priority review. The value is in *catching disagreement as a safety signal*, not in boosting accuracy.

**Tier 3 — rigor, not invention (do these regardless):**
6. True external validation (train on APTOS, test on Messidor-2) — most teams skip this under time pressure.
7. A properly working Simulink model — differentiator by execution quality, since it's the toolbox most teams will rush.

---

## 7. Tooling & Learning Resources

**No MATLAB experience?** Do these in order:
1. **MATLAB Onramp** (MathWorks, free, ~2 hrs) — everyone, day 1.
2. Domain-specific onramp for your assigned module:
   - **Image Processing Onramp** — Modules 1 & 2 people
   - **Deep Learning Onramp** + Deep Network Designer app (GUI-based CNN building) — Modules 3 & 4 people
   - **Simulink Onramp** + **SimEvents tutorials** (discrete-event simulation specifically — not generic control-systems Simulink content) — Module 5 person, start day 1, dedicated
3. If you already know Python/PyTorch/OpenCV: search MathWorks' "for Python/TensorFlow/PyTorch users" comparison docs — faster than starting from zero.

**License:** check for a MathWorks Campus-Wide License via college IT/library first (most engineering colleges have one, covers all needed toolboxes for free). Fallback: free MathWorks Student license. Last resort: 30-day trial.

**Domain background (everyone, ~half day):**
- IDRiD dataset paper — clearest technical description of what each lesion type looks like, written for engineers.
- APTOS 2019 Kaggle "Discussion"/"Notebooks" tabs — see how others structured the same problem.
- Search "International Clinical Diabetic Retinopathy Severity Scale PDF" — short, readable reference for the 0–4 scale.

---

## 8. Key Risks to Keep in Mind

- **Microaneurysm detection** is a genuine research-grade problem — don't plan around hitting full clinical accuracy here in two weeks.
- **Sensitivity/specificity targets (>90%/>85%)** require honest train/test discipline — validating on Messidor-2 (separate dataset) rather than a split of the training data is what makes the number trustworthy.
- **IDRiD segmentation set is small** (~81 fully masked images) — expect the MA/lesion segmentation model to be fragile; heavy augmentation helps but won't fully solve it.
- **Simulink is the steepest learning curve for a CS/ML-background team** — assign one dedicated owner early, don't let it become a last-minute afterthought.
