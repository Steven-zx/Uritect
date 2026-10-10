# Progressive clinical checklist — 2026-10-05

Implemented from the research team's attached proposal. The request authorizes the questionnaire redesign only; candidate Bayesian formula changes remain deferred.

## Flow

1. Basic information: age range and sex. Ages outside 18–64, or uncertain age, retain unavailable numerical research estimation while continuing to safety/follow-up.
2. Sex-specific pathway: pregnancy and menstruation/bleeding for females; urinary symptoms for both sexes; existing population exclusions remain. Females retain alternate-cause questions; males retain diabetes/STI exclusions. Pregnancy is displayed directly but mapped to the existing confirmed-nonpregnant variable with inverted Yes/No values.
3. Safety: one explicit review of the listed warning symptoms. No confirms their absence collectively; Yes or Not sure reveals individual questions. Safety remains available with rejected scans. All existing safety variables remain; swelling reveals the persistence question.
4. Follow-up context: one previous-abnormal/repeat-history question. Protein/blood abnormalities, unreadable results, visible blood, swelling or reported/uncertain history reveal the relevant context and repeat-confirmation questions. Reliable negative protein/blood with no related symptoms or history hides the long detail list. Previous abnormal history can still be reported even when the current scan is negative.
5. Test quality: a summary question with expiry, damage, supported profile and reading-time instructions. Yes/Not sure reveals the existing technical questions. Any reported or uncertain procedure problem prevents strip-based interpretation; the app does not automatically verify these requirements.

The compact normal pathway still asks the current model's necessary exclusions. Removing them before final methodology changes would incorrectly broaden eligibility. Follow-up context retains a short history question even for negative pads so a previously persistent abnormality is not silently lost.

## Answer and result contract

- Visible questions use Yes/No/Not sure; required pathway and safety questions must receive an explicit response before moving on. Not sure is a valid response and is preserved.
- `ClinicalChecklistResult.answers` stores explicit answers and group review responses. Existing positive flags remain available through selectedSymptoms for the unchanged numerical/rule engines.
- `questionnaireVersion` is progressive_checklist_v1_20261005; the input gate policy is interpretation_gates_v2_20261005. Bayesian model IDs and all numeric priors/LRs are unchanged.
- Incomplete/uncertain safety or urinary answers and uncertain female alternate-cause findings prevent an ordinary posterior for the new questionnaire. Reported serious findings still reach the safety engine independently.
- Uncertain quality marks protein/blood unreliable and retains the existing retake/safety priority. The result page warns that incomplete safety answers cannot exclude unreported warning symptoms.
- History preserves explicit answers through JSON; review shows Yes, No, Not sure, or Not asked/unanswered. Legacy records lack explicit negatives and are not retroactively labelled No.
- Changing sex clears hidden sex-specific responses. Expanding a previously denied safety group clears collective negative answers so individual responses are actually collected. Repeated taps on the same group choice do not erase reported details.

No proposed 6.1/0.2 female or 4.87/0.48 male construction was installed. The current female symptom factors and current male ordered LE/nitrite branches remain until a reviewed methodology change is authorized. Menstruation stays context for existing follow-up rules; no new adjustment to the Bayesian percentage was added.

## Verification and handoff

Existing parameter, clinical rule, saved-history, camera, startup and retake regressions remain in the full suite. New tests cover explicit-answer JSON, hidden response cleanup, collective safety answers, unknown-answer posterior gates, safety priority with uncertain quality, male-only UI, conditional renal details and quality expansion.

User requested APK preparation for later testing. Pilot build 1.4.0+11, manifest and test log are archived under output/device_pilot/2026-10-05. No physical questionnaire walkthrough or installation is claimed. Test later with synthetic male/female cases, an out-of-range age, pregnancy Not sure, negative pads with previous abnormal history, a failed scan with a serious symptom, and quality Not sure. Do not save synthetic answers as patient findings.
