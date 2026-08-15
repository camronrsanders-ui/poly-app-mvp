# Polycircle Legal Readiness Hub

**Internal control document — not a public legal policy and not legal advice.**  
**Last reviewed against primary sources:** 2026-08-15  
**Status:** ACTIVE PRE-RELEASE LEGAL CONTROL CENTER

This file is the single internal index and risk register for legal/compliance work associated with Polycircle. It is intentionally conservative because Polycircle is an adults-only dating/social product that handles user-generated content, private messages, profile photos, sexual-orientation/relationship information, safety reports, and other sensitive personal information.

This file does **not** guarantee that Polycircle cannot be sued, investigated, rejected by an app store, or found noncompliant. No document can provide that guarantee. Its purpose is to reduce preventable legal risk, keep implementation and public promises aligned, and make unresolved legal decisions visible before launch.

A qualified attorney familiar with consumer internet products, privacy, user-generated content, dating/social platforms, and the intended launch jurisdictions must review the final public legal documents and high-risk workflows before public distribution.

---

## 1. Non-negotiable release rule

Polycircle must not be represented internally or publicly as “fully legally compliant,” “lawsuit-proof,” “100% safe,” “fully verified,” or similarly absolute unless a specific claim has a documented factual/legal basis and is appropriately qualified.

No public launch should occur until every item marked **RED — PUBLIC-LAUNCH BLOCKER** in this file is resolved, expressly accepted by qualified counsel, or removed because the related feature/jurisdiction will not ship.

Private Vault remains outside the released product until its separate safety/privacy/legal gate passes. Real subscriptions and real advertising remain outside production until their separate gates pass.

---

## 2. Legal owner facts that must be decided before publication

**RED — PUBLIC-LAUNCH BLOCKER**

Do not publish final Terms, Privacy Policy, DMCA notice, marketing email, paid subscription terms, or formal legal notices until these are known:

- Legal operator/entity name: **[REQUIRED]**
- Entity type and formation jurisdiction: **[REQUIRED]**
- Principal business address: **[REQUIRED]**
- Public support contact: **[REQUIRED]**
- Privacy-rights contact: **[REQUIRED]**
- Safety / nonconsensual-intimate-image contact: **[REQUIRED]**
- DMCA designated-agent contact: **[REQUIRED IF SAFE-HARBOR STRATEGY ADOPTED]**
- Legal-process / law-enforcement contact: **[REQUIRED]**
- Security-vulnerability contact: **[REQUIRED]**
- Launch countries/states/storefronts: **[REQUIRED]**
- Registered agent/business registrations as required by entity jurisdiction: **[COUNSEL/ACCOUNTANT REVIEW]**

Use business contact information rather than casually publishing a founder’s personal home address or private email. Some laws and platform processes require a physical or mailing address; counsel should select an appropriate compliant business address, P.O. Box, or commercial mailbox where permitted.

Entity formation can reduce some business risk but is not a magic shield against personal liability, fraud, personal misconduct, guarantees, tax obligations, or statutory duties. Maintain the entity correctly, separate personal/business finances, execute contracts in the entity’s name, and obtain accounting/legal advice.

---

## 3. Canonical legal-document map

The following files already exist. This hub is the control center; it does not replace the public-facing documents that must eventually be published.

| Subject | Current repository document | Internal status |
|---|---|---|
| Public Terms candidate | `../terms-draft.md` | Canonical long-form public Terms draft; NOT FOR PUBLICATION until counsel review |
| Alpha acceptance text | `../terms-of-use-draft.md` | Temporary product/test acceptance fixture (`2026-08-alpha-v1`), not final public Terms |
| Privacy Policy | `../privacy-policy-draft.md` | NOT FOR PUBLICATION; operator, rights, retention, processors, international language unresolved |
| Community Guidelines | `../community-guidelines.md` | Safety/product draft; needs final legal/operations alignment |
| Data retention | `../data-retention-matrix.md` | Engineering/legal decision tracker; all unresolved durations must close before public launch |
| Data lifecycle | `../data-lifecycle.md` | Implementation reference |
| Data access/export | `../data-access.md` | Rights/export implementation reference |
| Account deletion | existing account-deletion implementation/docs | Must be verified end-to-end and synchronized with public disclosures |
| Incident response | `../incident-response.md` | Operational foundation; jurisdiction-specific notification matrix still required |
| Moderation | `../moderation-runbook.md` | Operational foundation; must be exercised with real operators/data before launch |
| Age/UGC/store compliance | `../app-store-age-ugc-compliance.md` | Engineering/policy foundation, not a legal certification |
| Monetization | `../monetization-architecture.md` | Real billing and ads remain OFF |
| Security | `../security-review-checklist.md`, `../abuse-threat-model.md`, `../backup-recovery.md` | Release evidence, not a warranty of security |
| Accessibility | `../accessibility-review.md` | Product review; counsel should determine jurisdiction-specific legal obligations |

### Terms drift rule

`../terms-draft.md` is the canonical candidate for eventual public Terms. `../terms-of-use-draft.md` exists only to exercise the current alpha acceptance gate. Before public launch, one counsel-reviewed Terms document/version must become authoritative and the product acceptance version must match it exactly. Do not allow two contradictory public Terms to exist.

---

## 4. Master legal risk register

### RED — PUBLIC-LAUNCH BLOCKERS

1. **Identify the legal operator and public business/legal contacts.**
2. **Counsel-review and finalize Terms, Privacy Policy, Community Guidelines, retention/deletion disclosures, and moderation promises.**
3. **Implement a TAKE IT DOWN Act notice-and-removal process** for nonconsensual intimate images, including a clear public notice, a request route available to people without a Polycircle account, request tracking, a 48-hour operational deadline for valid requests, and reasonable efforts to remove known identical copies.
4. **Confirm and operationalize child-sexual-exploitation reporting obligations** under 18 U.S.C. § 2258A, including a designated internal point of contact, NCMEC CyberTipline provider/reporting process, evidence-preservation handling, and moderator training.
5. **Adopt a DMCA strategy.** If Polycircle seeks 17 U.S.C. § 512 hosting safe-harbor protection, register and publicly identify a designated DMCA agent, implement valid notice/counter-notice handling, and reasonably implement a repeat-infringer policy.
6. **Finalize retention/deletion rules** for messages, reports/evidence, protected media, deleted accounts, security logs, billing records (if added), and backups.
7. **Create a real privacy-rights intake process** for access, correction, deletion, export, appeal/verification as applicable; decide response ownership and identity-verification controls.
8. **Complete a launch-jurisdiction privacy-law matrix.** State privacy-law thresholds and special sensitive-data rules change over time. Do not assume one federal privacy policy is sufficient everywhere.
9. **Complete a breach-notification matrix and written security-program review.** Where Massachusetts 201 CMR 17.00 applies, maintain the required written information security program (WISP). Other states have separate breach/privacy requirements.
10. **Complete Apple App Privacy and Google Play Data Safety disclosures against the actual shipping binary and SDK list.** They must match runtime behavior, not roadmap intent.
11. **Publish a real, active public Privacy Policy webpage.** Google Play requires an accessible web policy and account-deletion web resource for account-creation apps; Apple requires an accessible privacy policy and in-app account-deletion initiation.
12. **Publish an external account-deletion page/path** in addition to the in-app deletion workflow for Google Play.
13. **Configure adult-only store controls.** For Google Play dating/matchmaking, use Restrict Minor Access and select the appropriate 18+ target audience; validate Apple age-rating/Declared Age Range behavior and store declarations.
14. **Complete “Polycircle” trademark clearance** before substantial public brand investment and filing. Search federal applications/registrations, state/common-law use, domains, app stores, and related dating/social services; have trademark counsel interpret conflicts.
15. **Confirm ownership of all code, artwork, logo, copy, photography, fonts/assets, and third-party dependencies.** Maintain license notices and obtain written IP assignment/confidentiality agreements from contractors/contributors where needed.
16. **Create a law-enforcement/civil-process policy** for subpoenas, warrants, emergency requests, preservation requests, user notice where lawful, and disclosure minimization.
17. **Create a trafficking/commercial-sex abuse policy and escalation path.** Do not design, market, or knowingly operate Polycircle to promote/facilitate prostitution or act in reckless disregard of sex trafficking; 18 U.S.C. § 2421A is a high-risk statute for interactive services.
18. **Make a deliberate geography decision.** If Polycircle will be offered to people outside the United States, complete the relevant privacy/consumer/platform review first. A non-U.S. entity can still be subject to GDPR when it offers services to or monitors people in the EU.
19. **Operational moderation must exist, not merely documentation.** Assign trained humans/owners, escalation authority, response tracking, restricted evidence access, appeal handling, and after-hours critical-safety procedure before public UGC scale.
20. **Obtain final qualified legal review before public distribution.** Record the date, scope, jurisdictions reviewed, documents reviewed, and unresolved risks.

### YELLOW — MUST RESOLVE BEFORE RELATED FEATURE

- Real subscriptions / trials / paid boosts: billing legal gate below.
- Advertising or ad SDK: advertising/privacy gate below.
- Private Vault/intimate-media sharing: separate enhanced legal/safety review.
- Precise/live location: privacy/safety/legal review before collection.
- Selfie, face geometry, government ID, biometric identity verification: biometric/privacy/age-assurance legal review before collection.
- AI provider receiving member data: vendor/privacy review, disclosure/consent analysis, retention/training restrictions, and app-store disclosure update before integration.
- Voice/video calling or recording: wiretap/recording-consent and safety review by jurisdiction.
- Events/IRL meetups: premises/event waivers, insurance, age/alcohol, vendor, accessibility, and local-law review.
- Health/HIV-specific product features: health/privacy review before structured collection or inference.
- International launch: GDPR/UK/Canada/Australia/etc. review before those storefronts are intentionally targeted.

### GREEN — CURRENT RISK-REDUCTION FOUNDATIONS

These are useful controls, not legal certifications:

- 18+ product design and age-assurance foundation.
- Blocking/reporting/end-connection controls.
- Protected profile-photo processing/delivery architecture.
- Restrictive Firestore/Storage rules and App Check foundation.
- Data-access/export foundation.
- Account-deletion backend workflow.
- Moderation runbook and incident-response documentation.
- Privacy-sensitive Circle/discovery architecture.
- Real billing OFF; real ads OFF.
- Private Vault OFF.

---

## 5. Required public legal/safety pages before launch

**RED — PUBLIC-LAUNCH BLOCKER**

Polycircle should have stable public URLs for at least:

1. **Terms of Use** — final effective date/version, operator, eligibility, user content license, prohibited conduct, moderation, termination, fees if any, disclaimers/liability/dispute terms reviewed for launch jurisdictions.
2. **Privacy Policy** — actual collection/use/sharing, sensitive data, processors, retention, deletion, security, rights, international transfers if applicable, contact.
3. **Community Guidelines** — conduct and safety expectations.
4. **Account Deletion** — external web route explaining/requesting deletion as required by Google Play, consistent with the in-app workflow.
5. **Nonconsensual Intimate Image / TAKE IT DOWN notice and request form** — clear/conspicuous, available without an account, tracked operationally.
6. **Copyright / DMCA** — designated agent and notice/counter-notice route if Polycircle relies on § 512 safe harbor.
7. **Safety & Support contact** — clear route for ordinary support versus urgent platform safety concerns.
8. **Privacy Choices / Data Rights** — access, correction, deletion, export, opt-outs/limits where applicable.
9. **Legal Process / Law-Enforcement guidance** — optional public transparency page but internally mandatory policy/contact.
10. **Accessibility contact** — route to report accessibility barriers, without making promises the product cannot meet.

All pages must use the same legal entity name, product name, contact details, effective dates, and substantive promises. A store listing, website, app UI, Terms, Privacy Policy, and actual backend behavior must not contradict one another.

---

## 6. Federal consumer protection: truth, privacy, and security

### FTC Act / app marketing baseline

Treat every statement in the app, website, press kit, social post, investor/user promotion, influencer campaign, and app-store listing as a potential advertising claim.

Rules for Polycircle marketing:

- Do not claim “verified identity” unless the exact identity property was actually verified.
- Do not claim a Circle relationship is “verified” unless every represented person completed the defined mutual-verification process.
- Do not claim “100% private,” “unhackable,” “screenshot-proof,” “fully encrypted,” “guaranteed safe,” or similar absolutes unless technically and legally supportable.
- Do not imply that moderation eliminates assault, fraud, stalking, catfishing, or other offline risk.
- Do not hide material limitations in dense Terms when the product/marketing statement would otherwise mislead a reasonable user.
- Privacy/security promises must match production behavior continuously, not only at launch.
- Minimize collection and retention and restrict internal access according to need.

FTC guidance emphasizes truthful app claims, clear disclosures, privacy by design, consent for non-obvious/sensitive collection, reasonable security, and honoring privacy promises.

Primary sources:
- https://www.ftc.gov/business-guidance/resources/marketing-your-mobile-app-get-it-right-start
- https://www.ftc.gov/business-guidance/resources/app-developers-start-security
- https://www.ftc.gov/business-guidance/resources/start-security-guide-business

---

## 7. TAKE IT DOWN Act — nonconsensual intimate imagery

**RED — PUBLIC-LAUNCH BLOCKER**

The FTC began enforcing Section 3 of the TAKE IT DOWN Act on May 19, 2026. The law covers a broad range of platforms, including social, messaging, image/video-sharing, and similar UGC services. Because Polycircle includes UGC, messaging, and image functionality, the safe operational assumption is to treat it as a covered platform unless qualified counsel concludes otherwise.

Before public launch:

- Publish clear and conspicuous plain-language information describing the TIDA removal process.
- Provide a dedicated removal-request path that does not require a Polycircle account.
- Make the route easy to find from locations where intimate media can be exposed and from the public website.
- Assign a unique tracking/reference number to requests.
- Capture the information required by the statute; have counsel verify the final form fields and attestations against the current law.
- Immediately timestamp receipt and compute the statutory response deadline.
- For a valid request, remove the reported content and make reasonable efforts to find/remove known identical copies within **48 hours**.
- Record who acted, what was removed, when, why, and whether duplicate search/removal was completed.
- Notify the requester of outcome/status without exposing unnecessary private information.
- Build a narrowly scoped hash/fingerprint strategy for removed content only after privacy/security review; do not turn abuse prevention into a general intimate-image surveillance database.
- Coordinate evidence preservation with the separate NCMEC/legal-hold process where minors or criminal conduct may be involved.
- Never require a victim to contact the uploader before using Polycircle’s takedown process.

Primary FTC source:
- https://www.ftc.gov/business-guidance/resources/complying-take-it-down-act

The FTC’s guidance states that valid requests require removal of the content and known identical copies within 48 hours and that TIDA protections are not limited to people with platform accounts.

---

## 8. Child safety, CSAM, age, and COPPA

### 8.1 Adults-only product rule

Polycircle is an 18+ dating/social product. Confirmed minors must not receive a reduced/minor version of dating functionality; access is blocked.

Do not market to minors. Do not use child-oriented creative, influencers, ad targeting, keywords, or store settings that contradict the adult-only product designation.

Google Play currently requires apps whose core functionality is dating/matchmaking to use **Restrict Minor Access**. Select 18+ as the target audience and validate the real Play-delivered age behavior before distribution.

Primary Google sources:
- https://support.google.com/googleplay/android-developer/answer/16302250
- https://support.google.com/googleplay/android-developer/answer/16838200

### 8.2 18 U.S.C. § 2258A / NCMEC CyberTipline

**RED — PUBLIC-LAUNCH BLOCKER**

Counsel must determine and document Polycircle’s provider obligations under 18 U.S.C. § 2258A. The current statute imposes reporting duties on covered providers after actual knowledge of specified facts/circumstances involving apparent child sexual exploitation offenses and requires reporting to NCMEC’s CyberTipline as soon as reasonably possible.

Operational minimum before public UGC scale:

- designate a trained internal child-safety/legal point of contact;
- establish the provider/CyberTipline reporting workflow appropriate to Polycircle;
- create a written decision tree for suspected CSAM, grooming/enticement, minor sex trafficking, and related reports;
- prohibit moderators from unnecessarily downloading, duplicating, forwarding, or placing suspected CSAM into ordinary tickets/chats;
- preserve/report only through the controlled process required by law and counsel;
- restrict evidence access and audit every access;
- coordinate deletion requests/TIDA takedowns with legally required preservation rather than accidentally destroying required evidence;
- train moderators on what **not** to do with suspected illegal material.

The statute does not create a general requirement to proactively monitor all user communications merely to search for violations; actual-knowledge/reporting and lawful preservation obligations should be handled according to the statute and counsel.

Primary current statute:
- https://uscode.house.gov/view.xhtml?edition=prelim&num=0&req=granuleid%3AUSC-prelim-title18-section2258A

### 8.3 COPPA

Polycircle is not intended for children. COPPA can nevertheless matter if a general-audience online service has **actual knowledge** that it is collecting personal information from a child under 13. If Polycircle learns a specific account belongs to a child under 13, immediately block dating access and escalate to the child-safety/privacy process; do not simply leave the account operating because the Terms say “18+.” Counsel must determine the deletion/notice/reporting handling for the actual facts.

Primary FTC source:
- https://www.ftc.gov/business-guidance/resources/complying-coppa-frequently-asked-questions

---

## 9. Trafficking, prostitution facilitation, exploitation, and illegal services

**RED — PUBLIC-LAUNCH BLOCKER FOR POLICY/OPS**

18 U.S.C. § 2421A creates serious criminal/civil exposure for certain operation of an interactive computer service with intent to promote/facilitate prostitution and aggravated conduct involving reckless disregard of sex trafficking.

Polycircle’s product, marketing, ranking, moderation, and monetization must never be designed to facilitate commercial sexual exploitation or trafficking.

Required controls:

- Community Guidelines/Terms prohibit trafficking, exploitation, coercion, buying/selling people, and unlawful commercial sexual services.
- Reporting includes trafficking/exploitation routes with high-priority escalation.
- Do not sell or promote “visibility” products specifically designed to facilitate unlawful commercial sexual transactions.
- Do not ignore credible trafficking reports because an account is a paying user.
- Preserve/escalate evidence according to counsel and applicable law.
- Train moderators to distinguish consensual adult identity/sexual expression from indicators of coercion/exploitation; enforcement must not simply target LGBTQ+, ENM, or consensual adult sexuality.

Primary current statute:
- https://uscode.house.gov/view.xhtml?req=%28title%3A18+section%3A2421A+edition%3Aprelim%29

---

## 10. Copyright, user uploads, and DMCA

### 10.1 User-content rights

Final Terms should require members to have the rights/permissions necessary for content they upload and grant Polycircle a **narrow service license** sufficient to host, process, resize/re-encode, moderate, display to authorized recipients, transmit, back up where applicable, and remove submitted content. Do not take ownership of member content through unnecessarily broad boilerplate.

### 10.2 DMCA § 512 safe-harbor strategy

**RED — PUBLIC-LAUNCH BLOCKER**

Because Polycircle hosts user-generated photos/text/messages, counsel should adopt a § 512 strategy. To seek applicable hosting safe-harbor protection, the Copyright Office describes requirements including a reasonably implemented repeat-infringer policy, a designated/registered DMCA agent, public agent contact information, expeditious handling of valid notices, and counter-notice procedures.

Required operational work:

- register the designated agent with the U.S. Copyright Office;
- publish agent name/title, mailing address, phone, and email as required;
- calendar the designation renewal — Copyright Office guidance states designations expire after three years;
- create a valid notice intake checklist;
- remove/disable access expeditiously when a compliant notice requires it;
- notify the uploader as required by the safe-harbor procedure;
- accept/validate counter-notices;
- follow the statutory 10–14 business-day restoration framework where applicable unless the claimant files the required court action;
- maintain a reasonable repeat-infringer policy;
- prevent retaliation against good-faith copyright complainants/counter-claimants;
- keep DMCA records separate from ordinary moderation where practical.

Primary Copyright Office sources:
- https://www.copyright.gov/512/index.html
- https://www.copyright.gov/dmca-directory/faq.html

DMCA is not a substitute for the TAKE IT DOWN Act. A person depicted in an intimate photo may not own the copyright in that photo; TIDA/privacy/NCII processes must remain separately available.

---

## 11. Privacy and sensitive-data baseline

Polycircle should treat the following as **highly sensitive** even where a particular statute uses a narrower definition:

- sexual orientation;
- gender identity/expression and pronouns;
- relationship structure/status and Circle graph/content;
- private discovery preferences;
- message contents and metadata;
- reports/blocks/safety information;
- intimate-media activity;
- health/HIV information if entered;
- precise location if ever introduced;
- race/ethnicity, religion, political beliefs, disability information when supplied;
- age-assurance metadata;
- government ID/biometric data if ever introduced;
- authentication/security data;
- purchase/subscription history if monetization is enabled.

### 11.1 Universal internal privacy baseline

Even before a state-law threshold applies, Polycircle should aim to provide:

- reasonable access to account/profile data;
- correction of member-provided data;
- account/data deletion subject to narrowly documented lawful retention;
- export/portability of appropriate own-account data;
- clear privacy settings;
- data minimization;
- purpose limitation;
- retention limits;
- least-privilege internal access;
- no sale of intimate/sensitive identity, relationship, message, report, or precise-location data;
- no use of those categories for behavioral ad targeting;
- affirmative review/consent for materially new sensitive-data uses;
- a way to contact Polycircle about privacy rights.

### 11.2 California / state-law threshold review

California identifies categories such as precise geolocation, message content, sexual orientation/sex-life information, health, race/ethnicity, religion, biometrics, and certain credentials as sensitive personal information. CCPA applicability depends on statutory definitions/thresholds and facts; do not assume Polycircle is exempt or covered without a current threshold analysis.

Before public launch and at least annually thereafter, counsel should maintain a state privacy-law applicability matrix covering the launch states, thresholds, sensitive-data consent/limitations, universal opt-out signals where applicable, appeals, response periods, processor contracts, data-protection assessments, and sale/share/targeted-advertising rules.

Primary California source:
- https://oag.ca.gov/privacy/ccpa

### 11.3 Massachusetts information-security requirements

If Polycircle owns/licenses “personal information” about Massachusetts residents within the meaning of Massachusetts law, 201 CMR 17.00 requires a written comprehensive information security program with appropriate administrative, technical, and physical safeguards. Maintain a WISP/applicability determination rather than assuming the engineering security checklist alone satisfies the regulation.

Primary sources:
- https://www.mass.gov/regulations/201-CMR-1700-standards-for-the-protection-of-personal-information-of-ma-residents
- https://www.mass.gov/info-details/requirements-for-data-breach-notifications

### 11.4 International geography

Do not accidentally turn an intended U.S.-only beta into an unreviewed global launch. Decide storefront/geography intentionally.

The European Commission states that GDPR can apply to a company established outside the EU when it offers goods/services (paid or free) to people in the EU or monitors their behavior. If EU users will be targeted, complete GDPR legal-basis, special-category-data, transparency, rights, processor/DPA, international-transfer, security, breach, representative/DPO/DPIA, age, and supervisory-authority analysis before enabling those storefronts.

Primary EU source:
- https://commission.europa.eu/law/law-topic/data-protection/rules-business-and-organisations/application-regulation/who-does-data-protection-law-apply_en

Apply the same “review before targeting” rule to the UK, Canada, Australia, and every additional launch jurisdiction.

---

## 12. Privacy Policy publication gate

**RED — PUBLIC-LAUNCH BLOCKER**

`../privacy-policy-draft.md` already identifies important implementation facts but is explicitly not ready for publication.

Before finalizing it:

- fill the legal operator/contact fields;
- reconcile every collected/transmitted data category against the shipping binary and Firebase/cloud configuration;
- identify every processor/subprocessor actually used at launch;
- describe each purpose accurately;
- disclose profile/discovery/Circle/message/photo/report/account/security behavior without exposing security-sensitive implementation details;
- finalize exact retention/deletion rules;
- document lawful safety/legal holds and their limits;
- describe privacy-rights request methods and verification;
- describe international transfers only if applicable and accurate;
- describe age-assurance data actually retained;
- make any subscription/advertising sections conditional on those features actually shipping;
- do not promise encryption, anonymity, deletion timing, moderation timing, or security guarantees that engineering/operations cannot deliver;
- record effective date and material-change communication procedure.

Google Play requires a public privacy policy with developer/app identification, data collection/use/sharing, security handling, retention/deletion, and contact information, accessible on a public active URL and in the app. Apple likewise requires privacy-policy access and accurate disclosure of collection, sharing, retention/deletion, and consent practices.

Primary platform sources:
- https://support.google.com/googleplay/android-developer/answer/10144311
- https://developer.apple.com/app-store/review/guidelines/

---

## 13. Apple App Store legal/policy gate

**RED — DISTRIBUTION BLOCKER**

Before App Store submission:

- final Privacy Policy URL exists and is accessible in-app and in App Store Connect;
- App Privacy answers are reconciled to the shipping app and every third-party SDK;
- private messaging is disclosed under the appropriate Apple user-content/message data category;
- sensitive information such as sexual orientation is classified accurately;
- photos/videos, user IDs, coarse/precise location (if any), purchases (if any), diagnostics/analytics (if any), and other collected categories are accurately declared;
- account creation has an in-app account-deletion initiation path;
- age rating and adult/UGC declarations match the product;
- review notes accurately explain age assurance, moderation, reporting/blocking, protected media, and any restricted/test account access;
- subscriptions, if enabled later, satisfy StoreKit/App Store requirements and are accurately described;
- no app-store screenshot/copy promises features that are disabled or unavailable.

Primary Apple sources:
- https://developer.apple.com/app-store/review/guidelines/
- https://developer.apple.com/app-store/app-privacy-details/

Apple’s App Privacy guidance specifically treats in-app private messaging as a message data type that must be considered for disclosure and identifies sexual orientation as sensitive information.

---

## 14. Google Play legal/policy gate

**RED — DISTRIBUTION BLOCKER**

Before Google Play submission:

- publish/link the Privacy Policy in Play Console and in-app;
- complete Data Safety based on actual runtime/SDK behavior;
- provide both an **in-app deletion path** and an **external web deletion resource**;
- ensure deletion actually removes associated account data except narrowly disclosed legitimate retention; freezing/deactivation alone is not deletion;
- select the appropriate 18+ target audience;
- enable Restrict Minor Access for the dating/matchmaking product;
- complete content rating and all required App Content declarations;
- review every third-party SDK for Play User Data compliance;
- if location permissions are added, use the minimum necessary scope and update disclosures;
- accurately declare whether ads are present;
- keep real ad SDKs OFF until the ad legal gate passes.

Primary Google sources:
- https://support.google.com/googleplay/android-developer/answer/10144311
- https://support.google.com/googleplay/android-developer/answer/13327111
- https://support.google.com/googleplay/android-developer/answer/16302250
- https://support.google.com/googleplay/android-developer/answer/10787469

---

## 15. Account deletion, retention, legal holds, and backups

**RED — PUBLIC-LAUNCH BLOCKER**

Account deletion must be both legally defensible and technically true.

Before launch:

- close every unresolved row in `../data-retention-matrix.md`;
- test normal deletion and partial-failure recovery against staging;
- document which records are deleted immediately, tombstoned, retained temporarily, or legally preserved;
- document backup retention/expiry and ensure public wording does not claim instantaneous deletion from immutable backups if that is not true;
- distinguish fraud/security/legal-evidence preservation from indefinite “just in case” retention;
- create a legal-hold process with authorized approver, matter/reason, scope, start date, review date, and release date;
- ensure a legal hold cannot silently become permanent unrelated product retention;
- ensure account deletion does not trap a subscriber; subscription management/cancellation must remain reachable according to store/legal requirements;
- do not require acceptance of newly revised participation Terms merely to exercise deletion/data rights or manage an existing paid subscription.

---

## 16. Security, WISP, breach response, and vulnerability handling

Security failures involving a dating app can expose unusually sensitive information, so legal and technical security controls must be joined.

Before public launch:

- assign a named internal security owner;
- maintain/update the engineering security review and threat model;
- maintain a written information security program/applicability determination for jurisdictions that require one;
- create an incident severity classification;
- create a current state-by-state breach-notification matrix with counsel;
- define what starts the breach-notification clock in each applicable jurisdiction;
- preserve incident evidence under restricted access;
- document processor/vendor incident-notification obligations;
- maintain a vulnerability-reporting contact and safe intake procedure;
- maintain dependency patching and credential/secret rotation procedures;
- never conceal a legally reportable breach or make misleading “no data was affected” claims before investigation supports them.

FTC security guidance emphasizes collecting only needed data, access control, secure storage/transmission, service-provider diligence, secure development/testing, and ongoing patching.

Primary source:
- https://www.ftc.gov/business-guidance/resources/app-developers-start-security

---

## 17. Messages, law enforcement, subpoenas, and emergency disclosures

**RED — PUBLIC-LAUNCH BLOCKER FOR OPERATIONS**

Because Polycircle stores private messages and member records, do not let ordinary support/moderation staff improvise disclosures to police, attorneys, employers, spouses/partners, family members, schools, reporters, or private investigators.

Create a written legal-process policy that requires:

- centralized legal-process intake;
- identity/agency verification;
- validation of jurisdiction and type/scope of legal process;
- counsel review for compelled disclosure when appropriate;
- data minimization to the lawful scope;
- preservation-request tracking/expiration;
- user notice when legally permitted and appropriate;
- emergency request standards and documentation;
- immutable audit record of what was disclosed and why;
- no disclosure of unrelated intimate/relationship/message information simply because it is technically accessible.

The Stored Communications Act restricts voluntary disclosure of certain communication contents/records and separately governs compelled disclosure and emergency exceptions. Counsel should determine Polycircle’s provider classification and exact process before launch.

Primary current statutes:
- https://uscode.house.gov/view.xhtml?edition=prelim&num=0&req=granuleid%3AUSC-prelim-title18-section2702
- https://uscode.house.gov/view.xhtml?edition=prelim&num=0&req=granuleid%3AUSC-prelim-title18-section2703

---

## 18. Moderation, negligence risk, and safety promises

Moderation should reduce harm without creating promises Polycircle cannot reliably fulfill.

Required legal/operations principles:

- Guidelines/Terms say what conduct is prohibited and reserve proportionate enforcement discretion subject to applicable law.
- Do not promise every report is reviewed within a specific time unless operations can meet it consistently; TIDA’s statutory deadline is different and must be met.
- High-risk categories (minor safety, credible threats, trafficking, NCII, suspected CSAM) have separate escalation rules.
- Moderator access to reports/messages/media is least-privilege and audited.
- Moderators do not browse private messages for curiosity or relationship disputes.
- Retaliatory/fraudulent reports are prohibited but reporting must remain accessible.
- Do not discriminate in enforcement because a member is LGBTQ+, polyamorous/ENM, monogamous, disabled, or otherwise part of a protected/personal group.
- Moderation approval of a photo/profile is not an identity guarantee or endorsement.
- Relationship cards are owner statements unless explicitly mutually verified.

---

## 19. Dating-product disclaimers and user-safety boundaries

Final Terms/product copy should accurately explain that:

- Polycircle is a technology platform, not an emergency service.
- Polycircle is not a medical, mental-health, legal, financial, or relationship-therapy provider merely because it offers educational resources.
- A match/Like/message/relationship label never equals consent.
- Members control their own boundaries and may block/end a connection.
- Polycircle cannot guarantee another member’s identity, intent, relationship status, criminal history, health status, or offline conduct unless a particular attribute is expressly verified through a defined process.
- Safety features reduce app-level access but cannot prevent screenshots, off-platform copying, stalking, assault, fraud, or other external conduct.
- Do not suggest that using Polycircle makes meeting strangers inherently safe.

Disclaimers cannot waive every legal duty. Their purpose is accurate expectation-setting, not an excuse for negligent security or ignored safety obligations.

---

## 20. Subscriptions, recurring charges, trials, refunds, and cancellation

**YELLOW — BLOCKER BEFORE REAL BILLING; currently OFF**

Do not enable real StoreKit/Google Play purchases until this gate is complete.

Before a tester can spend real money:

- final paid benefits are defined and truthful;
- each price, billing period, auto-renewal term, trial/intro period, post-trial price, and material restriction is clear before purchase;
- obtain the platform-required/legally sufficient affirmative purchase consent;
- no prechecked purchase or deceptive dark-pattern enrollment;
- provide a simple, easy-to-find manage/cancel route;
- Restore Purchases/account recovery is handled as required;
- backend verifies store transactions and handles refunds/revocations/grace/expiration;
- cancellation does not require accepting new Community participation Terms;
- safety, reporting, blocking, deletion, and core privacy remain available without payment;
- customer-support/refund escalation exists;
- Terms/Privacy/store metadata are updated before enabling the products;
- state/international automatic-renewal laws are reviewed for the launch jurisdictions.

FTC enforcement under ROSCA/FTC Act continues to emphasize clear material terms, express informed consent before recurring charges, and simple cancellation. Google Play separately requires clear price/frequency/renewal terms and an easy online cancellation path.

Primary sources:
- https://www.ftc.gov/news-events/news/press-releases/2026/05/shutterstock-pay-35-million-settle-ftc-allegations-over-illegal-subscription-cancellation-practices
- https://support.google.com/googleplay/android-developer/answer/9900533
- https://developer.apple.com/app-store/review/guidelines/

---

## 21. Advertising, targeting, influencers, reviews, and marketing

**YELLOW — BLOCKER BEFORE REAL ADS; currently OFF**

Advertising is secondary to subscriptions and must not be funded by exploiting intimate member data.

Before any ad SDK or personalized advertising ships:

- privacy/legal review the exact ad SDK/vendor and data flows;
- update Apple App Privacy and Google Data Safety;
- implement consent/privacy options required by applicable law/platform policy;
- prohibit sensitive targeting using sexual orientation, gender identity, relationship structure, Circle data, message content, report/block data, intimate media, age-assurance data, health/HIV data, precise location, race/religion/politics, or inferences from those categories;
- keep ads out of messages, Safety Center, report/block flows, age assurance, account deletion, Circle relationship details, and Private Vault;
- clearly label sponsored content so it cannot be mistaken for a member profile;
- create advertiser/category blocking and inappropriate-ad reporting;
- publish `app-ads.txt` if the selected network requires it;
- analyze Apple ATT/tracking and state targeted-ad/sale/share rules before enabling personalized ads.

### Influencers/testimonials/reviews

- Never buy or fabricate positive reviews.
- Never suppress negative reviews deceptively.
- Paid/free-product influencer relationships must be disclosed clearly where required.
- Do not script testimonials as if they are spontaneous member experiences.
- Do not claim statistics (“90% safer,” “best dating app,” etc.) without substantiation.

### Marketing email

Before sending promotional email at scale, implement CAN-SPAM-compliant sender/header/subject practices, appropriate ad identification, a valid postal address, and a functional opt-out process. Separate transactional/safety emails from marketing decisions.

Primary FTC source:
- https://www.ftc.gov/business-guidance/resources/can-spam-act-compliance-guide-business

SMS/push marketing, referral marketing, sweepstakes, affiliate programs, and international electronic marketing each require a separate review before launch.

---

## 22. Trademark, copyright, code provenance, and brand ownership

**RED — BRAND/IP READINESS**

### Polycircle name/logo

Before substantial launch spend:

- conduct a comprehensive clearance search for “Polycircle,” confusingly similar names, logo/design elements, and related dating/social/community services;
- search USPTO federal records, state records, common-law/internet use, domains, app stores, and relevant international databases for intended foreign markets;
- document the search date/results;
- have trademark counsel evaluate likelihood-of-confusion risk and filing strategy;
- consider federal registration for the name/logo once ownership/filing basis is clear.

A domain, social handle, app-store name, or business registration does not by itself establish that the mark is safe to use nationwide.

Primary USPTO sources:
- https://www.uspto.gov/trademarks/search/comprehensive-clearance-search-similar-trademarks
- https://www.uspto.gov/trademarks/search/federal-trademark-searching

### Code/assets

Maintain an IP provenance register covering:

- original source code;
- third-party/open-source packages and licenses;
- icons/fonts/stock assets;
- generated art/logo source files and rights;
- photographs/test data;
- copy/educational resources;
- contractor/employee contributions;
- AI-assisted outputs where provider terms/provenance matter.

Do not copy competitor UI artwork, photos, legal text, proprietary code, or branded assets merely because they are visible online.

Any contractor who creates code/design/content for Polycircle should have written confidentiality and IP-assignment terms appropriate to the engagement. “I paid for it” is not a substitute for confirming ownership/assignment language.

---

## 23. Vendors, Firebase/cloud, DPAs, and third-party SDKs

Before public launch maintain a live vendor/subprocessor register containing:

- vendor/service;
- purpose;
- categories of data received;
- processing/storage locations if relevant;
- contract/terms/DPA link and date accepted;
- retention/deletion behavior;
- subprocessors;
- security documentation;
- breach-notification terms;
- whether data is used for vendor advertising/training/product improvement;
- owner/review date.

Firebase/Google Cloud and Apple/Google app-store services must be represented accurately. Any future analytics, crash reporting, AI, advertising, customer-support, email, moderation, identity/age-verification, payment, or marketing vendor triggers a privacy/security/legal review before production integration.

Do not let an SDK quietly collect data that the Privacy Policy/Data Safety/App Privacy forms say Polycircle does not collect.

---

## 24. Biometrics, identity documents, and age verification

**YELLOW — BLOCKER BEFORE FEATURE**

Current architecture should prefer platform age signals and minimal evidence rather than collecting identity documents directly.

Do not introduce selfie matching, facial recognition/face geometry, voiceprints, fingerprints, government-ID scans, or biometric templates until counsel completes a biometric/privacy analysis for every launch jurisdiction and engineering documents consent, purpose, retention/destruction, vendor use, security, breach response, and deletion.

A “verification” badge must state exactly what was verified. Age verification is not identity verification; email verification is not identity verification; photo moderation is not identity verification.

---

## 25. Accessibility, discrimination, and civil-rights risk

Maintain accessible design as a product and risk-control requirement. Counsel should determine which accessibility laws/standards apply based on entity, geography, and service facts.

Operational baseline:

- support screen readers/dynamic text/contrast/touch targets where technically feasible;
- provide an accessibility contact;
- do not require a disability disclosure merely to use ordinary functionality;
- do not make moderation/discovery decisions based on protected traits unless a lawful, documented safety/product reason exists;
- test age/safety systems for disparate failure modes and provide human escalation where appropriate;
- never market accessibility conformance at a level not actually tested.

See `../accessibility-review.md`.

---

## 26. Insurance and business risk transfer

**YELLOW — STRONGLY RECOMMENDED BEFORE PUBLIC LAUNCH**

Discuss with a broker/counsel:

- cyber/privacy liability and breach response;
- technology errors & omissions (Tech E&O);
- media liability / copyright / UGC coverage;
- commercial general liability;
- directors & officers coverage if/when investors/company structure warrant it;
- employment practices if hiring;
- event coverage if Polycircle hosts physical events.

Policy exclusions matter. A low-cost policy that excludes dating services, sexual-content claims, privacy statutes, biometric claims, or UGC may provide little protection. Give the broker an accurate product description.

---

## 27. Contractors, employees, moderators, and confidentiality

Before anyone other than the founder/authorized owner receives privileged system access:

- written confidentiality obligations;
- IP assignment/invention ownership as appropriate;
- role-based access and least privilege;
- security training;
- privacy/moderation/evidence-handling training;
- immediate offboarding/revocation procedure;
- conflict-of-interest and moderator-abuse policy;
- prohibition on downloading/member-data browsing outside job need;
- auditable admin actions;
- vendor/contractor data-processing terms where applicable.

Do not allow moderators to use member photos/messages as examples in personal chats, portfolios, social posts, or training materials without a lawful approved basis.

---

## 28. Records, complaints, evidence, and legal holds

Maintain controlled records for:

- legal-policy versions and acceptance dates;
- privacy-rights requests and resolution;
- TIDA requests and 48-hour actions;
- DMCA notices/counter-notices;
- NCMEC/CyberTipline-related internal case references under restricted access;
- subpoenas/warrants/preservation/emergency requests;
- significant moderation appeals;
- security incidents/breach decisions;
- store submissions/privacy declarations;
- vendor reviews/DPAs;
- subscription/refund complaints if billing is enabled;
- legal/counsel signoffs.

Do not retain evidence forever merely because it is “legal.” Every legal/safety retention category needs an authority/purpose, access rule, review schedule, and destruction/release procedure.

---

## 29. Feature-change legal review triggers

A new legal review is mandatory **before** shipping any change that materially adds:

- a new category of personal/sensitive data;
- precise/live/background location;
- contact-book import;
- biometric/selfie/ID verification;
- AI processing of member content;
- audio/video calls or recording;
- health/STI/HIV structured data;
- private/intimate media;
- public posts/groups/forums beyond current profiles;
- advertising or tracking SDKs;
- subscriptions, trials, virtual currency, boosts, or paid visibility;
- referral rewards/sweepstakes;
- background checks;
- third-party data enrichment;
- data sale/share/targeted advertising;
- international storefront availability;
- physical events;
- minors/teen access (which is presently prohibited);
- law-enforcement data portal;
- relationship verification involving another person’s identity.

Engineering must not ship first and “update the Privacy Policy later.” Legal/privacy review is part of the design gate.

---

## 30. Public claims prohibited without proof/review

Do not publish these or close variants casually:

- “100% safe”
- “lawsuit-proof”
- “fully compliant everywhere”
- “anonymous” when accounts can be reidentified internally
- “end-to-end encrypted” unless actually implemented/audited as such
- “we never share data” if processors receive data
- “we delete everything instantly” if legal holds/backups remain
- “verified user/person/relationship” without defined verification
- “screenshots are impossible”
- “private media can never be copied”
- “AI does not use your data” unless every relevant vendor/data flow supports that claim
- “we do not collect location” if SDK/IP-derived location is collected
- “free” where auto-renewal/paid conditions are not conspicuous
- safety/performance/health statistics without substantiation.

---

## 31. Recommended launch geography rule

The lowest-risk default is to launch only in jurisdictions that have been deliberately reviewed and configured in the app stores. Do not leave every country/storefront enabled simply because it is technically easy.

For each launch geography record:

- consumer/privacy laws reviewed;
- minimum age/age-assurance issues;
- dating/sexual-content restrictions;
- data localization/transfer issues;
- electronic marketing rules;
- subscription/auto-renewal rules;
- content/NCII/child-safety obligations;
- law-enforcement disclosure rules;
- tax/business registration issues;
- legal contact/representative needs;
- app-store availability decision.

---

## 32. Counsel review packet — questions to resolve

Give counsel this hub plus the product/security docs and ask for written decisions on at least:

1. What legal entity should operate Polycircle and in what jurisdiction?
2. What U.S. states/countries can the first beta/public launch reasonably target?
3. Final Terms: governing law, venue/arbitration/class waiver (if any), warranty/liability language, content license, termination/appeal language.
4. Final Privacy Policy and privacy-law applicability/threshold matrix.
5. TAKE IT DOWN Act applicability and exact notice/form/duplicate-removal workflow.
6. 18 U.S.C. § 2258A/NCMEC provider obligations and evidence-preservation process.
7. DMCA § 512 agent/notice/counter-notice/repeat-infringer implementation.
8. Stored Communications Act/legal-process classification and disclosure policy.
9. Trafficking/commercial-sex policy under 18 U.S.C. § 2421A and related law.
10. Final message/report/media/security-log/backup retention periods.
11. State breach-notification and WISP obligations.
12. CCPA/other state sensitive-data rights and whether universal privacy controls should be offered.
13. International/GDPR scope or storefront restrictions.
14. Trademark clearance/registration for Polycircle/logo.
15. Open-source/code/content ownership and contractor IP agreements.
16. Subscription/auto-renewal terms before billing goes live.
17. Advertising/targeting rules before ads go live.
18. Insurance coverage appropriate to a dating/social UGC platform.
19. Accessibility obligations and public claims.
20. Whether any other dating-service-specific state/local requirements apply to the planned launch footprint.

Record counsel’s answer, date, jurisdiction, and any conditions rather than relying on verbal memory.

---

## 33. Legal signoff record

No boxes should be marked complete without evidence.

| Gate | Owner | Evidence / date | Status |
|---|---|---|---|
| Legal entity/operator identified | — | — | OPEN |
| Final launch geography approved | — | — | OPEN |
| Final Terms counsel-reviewed | — | — | OPEN |
| Final Privacy Policy counsel-reviewed | — | — | OPEN |
| Community Guidelines aligned | — | — | OPEN |
| TAKE IT DOWN process live/tested | — | — | OPEN |
| §2258A/NCMEC process approved/tested | — | — | OPEN |
| DMCA agent/process live | — | — | OPEN |
| Privacy-rights workflow tested | — | — | OPEN |
| Retention matrix finalized | — | — | OPEN |
| Account deletion web + in-app tested | — | — | OPEN |
| State privacy/breach matrix completed | — | — | OPEN |
| WISP/applicability review completed | — | — | OPEN |
| Apple privacy/store declarations reconciled | — | — | OPEN |
| Google Data Safety/store declarations reconciled | — | — | OPEN |
| Adult-only store controls validated | — | — | OPEN |
| Law-enforcement/legal-process procedure approved | — | — | OPEN |
| Trademark clearance completed | — | — | OPEN |
| IP/license provenance audit completed | — | — | OPEN |
| Vendor/DPA/subprocessor register completed | — | — | OPEN |
| Insurance decision documented | — | — | OPEN |
| Moderator legal/safety training exercised | — | — | OPEN |
| Final legal launch signoff | — | — | OPEN |

---

## 34. Primary-source register

Re-check these shortly before every public-store submission because laws/policies change.

### Federal / U.S.

- FTC — TAKE IT DOWN Act business guidance: https://www.ftc.gov/business-guidance/resources/complying-take-it-down-act
- U.S. Code — 18 U.S.C. § 2258A: https://uscode.house.gov/view.xhtml?edition=prelim&num=0&req=granuleid%3AUSC-prelim-title18-section2258A
- FTC — COPPA FAQ: https://www.ftc.gov/business-guidance/resources/complying-coppa-frequently-asked-questions
- U.S. Code — 18 U.S.C. § 2421A: https://uscode.house.gov/view.xhtml?req=%28title%3A18+section%3A2421A+edition%3Aprelim%29
- U.S. Code — 18 U.S.C. § 2702: https://uscode.house.gov/view.xhtml?edition=prelim&num=0&req=granuleid%3AUSC-prelim-title18-section2702
- U.S. Code — 18 U.S.C. § 2703: https://uscode.house.gov/view.xhtml?edition=prelim&num=0&req=granuleid%3AUSC-prelim-title18-section2703
- U.S. Copyright Office — § 512: https://www.copyright.gov/512/index.html
- U.S. Copyright Office — DMCA agent directory FAQ: https://www.copyright.gov/dmca-directory/faq.html
- FTC — Marketing Your Mobile App: https://www.ftc.gov/business-guidance/resources/marketing-your-mobile-app-get-it-right-start
- FTC — App Developers: Start with Security: https://www.ftc.gov/business-guidance/resources/app-developers-start-security
- FTC — CAN-SPAM guide: https://www.ftc.gov/business-guidance/resources/can-spam-act-compliance-guide-business
- USPTO — trademark clearance: https://www.uspto.gov/trademarks/search/comprehensive-clearance-search-similar-trademarks

### State examples / applicability work

- California CCPA: https://oag.ca.gov/privacy/ccpa
- Massachusetts 201 CMR 17.00: https://www.mass.gov/regulations/201-CMR-1700-standards-for-the-protection-of-personal-information-of-ma-residents
- Massachusetts breach notification: https://www.mass.gov/info-details/requirements-for-data-breach-notifications

### Apple

- App Review Guidelines: https://developer.apple.com/app-store/review/guidelines/
- App Privacy Details: https://developer.apple.com/app-store/app-privacy-details/

### Google Play

- User Data policy: https://support.google.com/googleplay/android-developer/answer/10144311
- Account deletion: https://support.google.com/googleplay/android-developer/answer/13327111
- Age-Restricted Content and Functionality: https://support.google.com/googleplay/android-developer/answer/16302250
- Data Safety: https://support.google.com/googleplay/android-developer/answer/10787469
- Subscriptions: https://support.google.com/googleplay/android-developer/answer/9900533

### International scope

- European Commission — GDPR territorial scope: https://commission.europa.eu/law/law-topic/data-protection/rules-business-and-organisations/application-regulation/who-does-data-protection-law-apply_en

---

## 35. Final rule

Legal readiness is a continuing product function, not a one-time Terms template.

Every promise must match the shipping app. Every new data flow must be reviewed before launch. Every mandatory safety process must have a real human owner. Every retention claim must match the database/backups. Every store disclosure must match the binary and SDKs. Every high-risk legal request must be logged and handled through the appropriate process.

**This file is the legal control center. It is not the final public contract, Privacy Policy, regulatory filing, DMCA registration, TAKE IT DOWN request system, NCMEC process, insurance policy, or attorney opinion. Those actions still have to be completed and evidenced.**
