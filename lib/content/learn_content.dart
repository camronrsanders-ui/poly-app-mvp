// Stage 1 Learn content for Polycircle.
//
// This data mirrors the approved content pack at
// docs (goal files): final-upgrade-learn-content-pack-2026-10-27.md —
// Section A (Get Help), Section B (Glossary), Section C (Learning
// Paths), Section D (Books & Voices). Edit the content pack first,
// then update this file to match.

class CrisisAction {
  const CrisisAction({required this.label, required this.uri});

  /// Short button label, e.g. 'Call', 'Text', or 'Call or text'.
  /// The number itself always stays visible as text next to it.
  final String label;

  /// A tel: or sms: URI launched externally when the button is tapped.
  final String uri;
}

class CrisisResource {
  const CrisisResource({
    required this.name,
    required this.contact,
    required this.note,
    required this.actions,
  });

  final String name;

  /// How to reach the resource, e.g. 'Call or text 988'. Always
  /// rendered as visible text — a number is never hidden behind only
  /// a button — and also selectable so members can copy it.
  final String contact;

  final String note;

  /// Tap-to-act actions (call / text) for this resource.
  final List<CrisisAction> actions;
}

class SupportEntry {
  const SupportEntry({
    required this.name,
    required this.detail,
    required this.url,
  });

  final String name;
  final String detail;

  /// Verified destination opened externally when the entry is tapped.
  final String url;
}

class SupportGroup {
  const SupportGroup({required this.heading, required this.entries});

  final String heading;
  final List<SupportEntry> entries;
}

class GlossaryTerm {
  const GlossaryTerm({
    required this.term,
    required this.category,
    required this.definition,
    required this.example,
  });

  final String term;
  final String category;
  final String definition;
  final String example;
}

class MicroRead {
  const MicroRead({required this.title, required this.description});

  final String title;
  final String description;
}

class LearningPath {
  const LearningPath({
    required this.title,
    required this.promise,
    required this.reads,
  });

  final String title;
  final String promise;
  final List<MicroRead> reads;
}

class BookRecommendation {
  const BookRecommendation({
    required this.title,
    required this.author,
    required this.readThisIf,
    required this.libraryUrl,
    this.libraryActionLabel = 'Find it free at your library',
    this.blurb,
  });

  final String title;
  final String author;

  /// The clause that follows 'Read this if…' in the content pack.
  final String readThisIf;

  /// Verified library search (OverDrive) for this title, opened
  /// externally from the book's primary action.
  final String libraryUrl;

  /// Label for the library action. Most books are findable free via
  /// OverDrive/Libby; a title that is not in the OverDrive catalog
  /// says so honestly and points at WorldCat library holdings
  /// instead.
  final String libraryActionLabel;

  final String? blurb;
}

class LearnContent {
  const LearnContent._();

  static const String helpCardHeading = 'You deserve support.';

  static const String helpCardIntro =
      'Reaching out is an ordinary, healthy act of care. These trusted '
      'resources are free, confidential, and here whenever you need '
      'them — for a crisis, or just to talk something through.';

  static const List<CrisisResource> crisisResources = [
    CrisisResource(
      name: '988 Suicide & Crisis Lifeline',
      contact: 'Call or text 988',
      note:
          'US, 24/7. For suicidal thoughts, emotional distress, or when you\'re worried about someone else.',
      actions: [CrisisAction(label: 'Call or text', uri: 'tel:988')],
    ),
    CrisisResource(
      name: 'Crisis Text Line',
      contact: 'Text HOME to 741741',
      note:
          'US, 24/7. Trained counselors by text, if talking on the phone feels like too much.',
      actions: [
        CrisisAction(label: 'Text', uri: 'sms:741741?body=HOME'),
      ],
    ),
    CrisisResource(
      name: 'The Trevor Project',
      contact: 'Call 1-866-488-7386',
      note:
          '24/7 support for LGBTQ young people. Chat and text options also available at thetrevorproject.org.',
      actions: [
        CrisisAction(label: 'Call', uri: 'tel:+18664887386'),
      ],
    ),
    CrisisResource(
      name: 'Trans Lifeline',
      contact: 'Call 877-565-8860',
      note: 'Peer support run by and for trans people.',
      actions: [
        CrisisAction(label: 'Call', uri: 'tel:+18775658860'),
      ],
    ),
    CrisisResource(
      name: 'National Domestic Violence Hotline',
      contact: 'Call 1-800-799-7233 or text START to 88788',
      note:
          '24/7. Safety planning and advocacy if a partner — any partner — is hurting or controlling you.',
      actions: [
        CrisisAction(label: 'Call', uri: 'tel:+18007997233'),
        CrisisAction(label: 'Text', uri: 'sms:88788?body=START'),
      ],
    ),
  ];

  static const List<SupportGroup> supportGroups = [
    SupportGroup(
      heading: 'Find a poly-friendly therapist',
      entries: [
        SupportEntry(
          name: 'Psychology Today directory',
          detail:
              'psychologytoday.com/us/therapists — filter by “polyamory” / non-monogamy under Issues, then check the profile actually names ENM experience, not just tolerance.',
          url: 'https://www.psychologytoday.com/us/therapists',
        ),
        SupportEntry(
          name: 'Kink Aware Professionals directory',
          detail:
              'kapprofessionals.org, run by the NCSF — therapists, doctors, and lawyers who are knowledgeable about kink and non-monogamy.',
          url: 'https://kapprofessionals.org',
        ),
        SupportEntry(
          name: 'Open Path Collective',
          detail:
              'openpathcollective.org — sliding-scale sessions (about \$30–\$80) with member therapists, if cost is the barrier.',
          url: 'https://openpathcollective.org',
        ),
      ],
    ),
    SupportGroup(
      heading: 'Community & learning',
      entries: [
        SupportEntry(
          name: 'Multiamory',
          detail:
              'multiamory.com — long-running podcast and community on modern relationships; home of the RADAR check-in framework used in this app.',
          url: 'https://www.multiamory.com',
        ),
        SupportEntry(
          name: 'Loving More',
          detail:
              'lovemore.com — nonprofit supporting polyamory education, community, and advocacy.',
          url: 'https://www.lovemore.com',
        ),
      ],
    ),
  ];

  /// Glossary categories in display order.
  static const List<String> glossaryCategories = [
    'Styles',
    'People & connections',
    'Feelings',
    'Agreements & health',
  ];

  static const List<GlossaryTerm> glossary = [
    GlossaryTerm(
      term: 'Polyamory',
      category: 'Styles',
      definition:
          'Practicing, or being open to, more than one romantic relationship at the same time, with the knowledge and consent of everyone involved. The emphasis is on ongoing emotional connection, not just sex.',
      example:
          'Sam is married to Jo and also dating Alex — everyone knows about everyone, and they all talk openly about it.',
    ),
    GlossaryTerm(
      term: 'Ethical non-monogamy (ENM)',
      category: 'Styles',
      definition:
          'The umbrella term for any relationship style where partners agree it\'s okay to have romantic or sexual connections with other people. Polyamory, open relationships, and swinging all sit under it. The "ethical" part means informed consent from everyone affected.',
      example:
          'When people ask what ENM means on a dating profile, it just signals "my relationships aren\'t exclusive, and everyone involved knows that."',
    ),
    GlossaryTerm(
      term: 'Open relationship',
      category: 'Styles',
      definition:
          'An existing couple agrees that one or both of them may have sexual (and sometimes romantic) connections outside the relationship. The shape varies a lot — some couples set detailed agreements, others keep it simple.',
      example:
          'Priya and Tom are each other\'s main partners, and they\'ve agreed either of them can go on dates with other people.',
    ),
    GlossaryTerm(
      term: 'Swinging',
      category: 'Styles',
      definition:
          'Couples (usually together) having sexual experiences with other people, often at parties, clubs, or with other couples. Swinging usually centers shared sexual adventure rather than separate romantic relationships.',
      example:
          'Dee and Marcus go to a swingers\' party together and only play with others as a couple.',
    ),
    GlossaryTerm(
      term: 'Metamour',
      category: 'People & connections',
      definition:
          'Your partner\'s partner — someone you\'re connected to through a shared partner, but not dating yourself. Metamours can be anything from strangers to close friends.',
      example:
          'Alex is my metamour: we both date Jordan, and we grab coffee now and then, but Alex and I aren\'t partners.',
    ),
    GlossaryTerm(
      term: 'Polycule',
      category: 'People & connections',
      definition:
          'The whole web of people connected through a set of polyamorous relationships — partners, metamours, and sometimes their partners too. The word plays on "molecule," since the connections form a shape.',
      example:
          'Our polycule is six people now: me, my two partners, my metamour, and her other partner.',
    ),
    GlossaryTerm(
      term: 'Dyad',
      category: 'People & connections',
      definition:
          'A relationship between exactly two people. Polyamorous networks are built out of dyads — each pair has its own relationship, even inside a group.',
      example:
          'Even in our triad, my dyad with Kai needs its own time and attention, separate from the group.',
    ),
    GlossaryTerm(
      term: 'Triad / throuple',
      category: 'People & connections',
      definition:
          'Three people who are all romantically involved with each other. "Throuple" is the casual version of the same word. Not every triad is equal on all sides — feelings and time often differ between each pair.',
      example:
          'The three of them became a triad after a year of dating in different combinations.',
    ),
    GlossaryTerm(
      term: 'Quad',
      category: 'People & connections',
      definition:
          'Four people in an interconnected romantic grouping. Often it\'s two couples who all became involved with each other, though it can form in other ways too.',
      example:
          'The quad started as two married couples who met at a meetup and slowly fell for each other.',
    ),
    GlossaryTerm(
      term: 'Comet partner',
      category: 'People & connections',
      definition:
          'A partner you don\'t see often — they pass through your life periodically, like a comet, with real warmth each time, and no expectation of daily contact in between. Common with long-distance or travel-heavy lives.',
      example:
          'My comet partner lives in another country; we spend an intense, lovely weekend together twice a year.',
    ),
    GlossaryTerm(
      term: 'Anchor partner',
      category: 'People & connections',
      definition:
          'A central, deeply committed partner in someone\'s life — the person (or people) they build their day-to-day around. Similar in weight to "primary partner," but without implying a ranked ladder of importance.',
      example:
          'Riley is my anchor partner — we share a home, a calendar, and big life decisions.',
    ),
    GlossaryTerm(
      term: 'Nesting partner',
      category: 'People & connections',
      definition:
          'A partner you live with — you share a "nest." Nesting describes the living arrangement, not necessarily rank: a nesting partner isn\'t automatically the most important partner.',
      example:
          'My nesting partner and I split rent and chores, and he also has a girlfriend across town.',
    ),
    GlossaryTerm(
      term: 'Primary / secondary partners',
      category: 'People & connections',
      definition:
          'Labels from hierarchical polyamory. A primary partner usually gets first claim on time, major decisions, and life structure; secondary partners have a real relationship that fits around that structure. Some people find the clarity helpful; others find the ranking itself hurtful, which is why newer terms like "anchor" and "nesting" exist.',
      example:
          'In their hierarchy, spouses are primaries, and each of them has a secondary partner they see on weekends.',
    ),
    GlossaryTerm(
      term: 'Hierarchy',
      category: 'Styles',
      definition:
          'An arrangement where some relationships are given structural priority over others — in decisions, time, living arrangements, or veto power. The opposite approach is non-hierarchical polyamory, where no relationship automatically outranks another.',
      example:
          'Their hierarchy means the married couple\'s shared home and finances come first when plans conflict.',
    ),
    GlossaryTerm(
      term: 'Kitchen table polyamory',
      category: 'Styles',
      definition:
          'A style where partners and metamours all know each other and are comfortable socializing together — in the image of everyone chatting around the kitchen table. It values friendliness and shared life, though nobody is required to be best friends.',
      example:
          'Kitchen table poly looks like my partners and my metamour all coming over for Sunday pancakes.',
    ),
    GlossaryTerm(
      term: 'Parallel polyamory',
      category: 'Styles',
      definition:
          'A style where partners know about each other but keep their relationships mostly separate — little or no social overlap, by mutual preference. Parallel is a valid choice, not a failure to do polyamory "right."',
      example:
          'I\'m parallel with my metamour: we\'re cordial, we have each other\'s numbers for emergencies, and that\'s exactly how we both like it.',
    ),
    GlossaryTerm(
      term: 'Solo polyamory',
      category: 'Styles',
      definition:
          'Practicing polyamory while keeping your own life structurally independent — you don\'t merge homes, finances, or identity with a partner, and you treat your relationship with yourself as the anchor. Solo poly people still form deep, committed relationships.',
      example:
          'I\'m solo poly: I love my partners, and I also love living alone and keeping my own household.',
    ),
    GlossaryTerm(
      term: 'Relationship anarchy',
      category: 'Styles',
      definition:
          'A philosophy that refuses to rank relationships by category — a friend can matter as much as a romantic partner, and no relationship type automatically gets priority or a fixed set of rules. Each connection is shaped by the people in it, not by a template.',
      example:
          'As a relationship anarchist, I don\'t assume my romantic partner outranks my best friend of fifteen years.',
    ),
    GlossaryTerm(
      term: 'Mono-poly relationship',
      category: 'Styles',
      definition:
          'A relationship where one person is monogamous and the other is polyamorous, by agreement. It asks a lot of communication from both sides: the monogamous partner gives informed consent without wanting outside connections themselves.',
      example:
          'She\'s mono and he\'s poly — she has no interest in dating anyone else, and she\'s genuinely fine that he does.',
    ),
    GlossaryTerm(
      term: 'Compersion',
      category: 'Feelings',
      definition:
          'Joy at a partner\'s happiness with someone else — the warm feeling of seeing someone you love light up in another connection. It\'s often described as the opposite of jealousy, though the two feelings can absolutely show up at the same time.',
      example:
          'Watching my partner get ready for his date, I felt this wave of compersion — he was glowing, and it made me happy.',
    ),
    GlossaryTerm(
      term: 'New relationship energy (NRE)',
      category: 'Feelings',
      definition:
          'The intense excitement, focus, and butterflies of a brand-new connection. NRE is normal and fun, but it can distort judgment and leave existing partners feeling dropped — naming it helps everyone handle it with care.',
      example:
          'Deep in NRE, he was texting his new partner constantly, and we had to talk about phone-free dinners again.',
    ),
    GlossaryTerm(
      term: 'Polysaturation',
      category: 'Feelings',
      definition:
          'The point where someone has as many relationships as they can genuinely care for well — adding more would take from the people already in their life (and from themselves). It\'s a capacity limit, not a lack of love.',
      example:
          'I\'m polysaturated at two partners: between them, work, and rest, my calendar and my heart are full.',
    ),
    GlossaryTerm(
      term: 'Boundaries vs. rules',
      category: 'Agreements & health',
      definition:
          'A boundary is a limit you set on yourself and your own participation ("I won\'t stay in a conversation where I\'m being yelled at"). A rule is a limit placed on someone else\'s behavior ("You\'re not allowed to date anyone taller than me"). Polyamory generally favors boundaries — you control you — while rules about other people\'s autonomy tend to backfire.',
      example:
          '"Text me before a first date so I know the plan" is an agreement; "I need to leave relationships where plans change without warning" is a boundary.',
    ),
    GlossaryTerm(
      term: 'Veto',
      category: 'Agreements & health',
      definition:
          'An arrangement where one partner can require another to end an outside relationship. Vetoes are controversial: they can feel protective early on, but they give one person power over a relationship they\'re not in, and the person who gets vetoed rarely consented to being disposable.',
      example:
          'They started with a veto agreement, then dropped it after realizing neither of them wanted that much power over the other\'s heart.',
    ),
    GlossaryTerm(
      term: 'Agreements',
      category: 'Agreements & health',
      definition:
          'The shared understandings partners make together about how their relationships will work — communication, time, safer sex, privacy, and more. Good agreements are mutual, specific, and revisited as things change; living documents, not rigid law.',
      example:
          'Our agreement is simple: we tell each other about new connections early, and we review everything twice a year.',
    ),
    GlossaryTerm(
      term: 'Check-in (RADAR)',
      category: 'Agreements & health',
      definition:
          'A regular, scheduled conversation where partners review how things are going and adjust. RADAR is a popular format from Multiamory: Review the time since last check-in, Agree on what to discuss, Discuss it, set Action points, then Reconnect with something warm. Small and regular beats big and rare.',
      example:
          'Our monthly RADAR takes an hour — we covered scheduling, one hurt feeling, and planned a proper date night.',
    ),
    GlossaryTerm(
      term: 'Safer sex & STI testing',
      category: 'Agreements & health',
      definition:
          'The practical layer of ENM: using barriers (condoms, dental dams) consistently, getting tested for sexually transmitted infections on a regular schedule, and sharing results honestly with partners. More connections means more shared responsibility — most poly people test every 3–6 months and always when partners or practices change.',
      example:
          'Before we stopped using condoms together, we both got full STI panels and shared our results.',
    ),
    GlossaryTerm(
      term: 'Fluid bonding',
      category: 'Agreements & health',
      definition:
          'Choosing to exchange bodily fluids with someone — most often, sex without barriers. Because it increases STI exposure across a whole network, fluid bonding is treated as a significant, explicit decision that involves everyone connected, not just the two people in the room.',
      example:
          'We\'re fluid bonded with each other, and we use barriers with anyone else — that\'s a polycule-wide agreement.',
    ),
    GlossaryTerm(
      term: 'Unicorn hunting',
      category: 'People & connections',
      definition:
          'A loaded term for an established couple looking for a (usually bisexual, usually female) third person to date both of them — often with rules that protect the couple and little real power for the person joining. It\'s criticized because the "unicorn" is expected to fit a pre-made structure, date both partners equally, and leave quietly if it doesn\'t work. Wanting a triad isn\'t the problem; treating a person as an accessory to a couple is.',
      example:
          'They realized their dating profile was unicorn hunting — "must date both of us, no separate relationships" — and rewrote it after reading how that lands on the other side.',
    ),
    GlossaryTerm(
      term: 'Chosen family',
      category: 'People & connections',
      definition:
          'The people you deliberately build family-like bonds with, related or not. Chosen family is central in queer and poly communities, where partners, metamours, and close friends may share holidays, caregiving, and everyday life.',
      example:
          'My chosen family — two partners, a metamour, and my best friend — does Thanksgiving together every year.',
    ),
    GlossaryTerm(
      term: 'Relationship smorgasbord',
      category: 'Styles',
      definition:
          'A tool (and mindset) for designing relationships à la carte instead of accepting a fixed package. You and each partner choose which elements you actually want together — romance, sex, cohabiting, finances, caregiving, public partnership — and skip the rest, per relationship.',
      example:
          'Using the smorgasbord, we picked romance, travel, and creative projects together — and happily skipped living together.',
    ),
    GlossaryTerm(
      term: 'Stepping off the relationship escalator',
      category: 'Styles',
      definition:
          'Choosing not to follow the default script — dating → exclusive → moving in → marriage → merged life — and instead letting each relationship find its own shape and pace. Polyamory is one way people step off, but so are solo living, committed non-marriage partnerships, and many other forms.',
      example:
          'Stepping off the escalator meant asking "what do we actually want?" instead of "what comes next?"',
    ),
  ];

  static const List<LearningPath> learningPaths = [
    LearningPath(
      title: 'New to polyamory — start here',
      promise:
          'The basics, in plain language, so your first steps feel informed instead of overwhelming.',
      reads: [
        MicroRead(
          title: 'What polyamory actually is (and isn\'t)',
          description:
              'The core ideas: consent, honesty, and many kinds of love — and how polyamory differs from cheating and from other ENM styles.',
        ),
        MicroRead(
          title: 'The starter vocabulary',
          description:
              'Metamours, polycules, NRE, and the dozen other terms you\'ll meet in the first month, decoded.',
        ),
        MicroRead(
          title: 'Is this right for you?',
          description:
              'Honest questions about time, jealousy, privacy, and desire to sit with before opening anything.',
        ),
        MicroRead(
          title: 'Unlearning the default script',
          description:
              'Where the "one true partner" story comes from, and how to start writing your own.',
        ),
      ],
    ),
    LearningPath(
      title: 'Talking so everyone feels heard',
      promise:
          'Communication skills that prevent small friction from becoming big hurt.',
      reads: [
        MicroRead(
          title: 'Saying the thing, kindly',
          description:
              'How to raise a hard topic directly, early, and without blame.',
        ),
        MicroRead(
          title: 'Requests vs. complaints',
          description:
              'Turning "you never make time for me" into an ask someone can actually say yes to.',
        ),
        MicroRead(
          title: 'The RADAR check-in',
          description:
              'A simple monthly structure for reviewing, discussing, and reconnecting before problems pile up.',
        ),
        MicroRead(
          title: 'Repair after a rupture',
          description:
              'What to do after a fight or a broken agreement: accountability, apology, and rebuilding trust.',
        ),
      ],
    ),
    LearningPath(
      title: 'Working through jealousy',
      promise:
          'Jealousy is information, not failure — learn to hear what it\'s pointing at.',
      reads: [
        MicroRead(
          title: 'Jealousy as a smoke detector',
          description:
              'Why jealousy usually signals an unmet need or a fear underneath, and how to find it.',
        ),
        MicroRead(
          title: 'In the moment: the first ten minutes',
          description:
              'Grounding steps for when the feeling spikes: pause, breathe, name it, don\'t text in a panic.',
        ),
        MicroRead(
          title: 'Talking about it without spiraling',
          description:
              'How to bring jealousy to a partner as information, not accusation — and how to receive it well.',
        ),
        MicroRead(
          title: 'Building security on purpose',
          description:
              'Rituals, reassurances, and agreements that genuinely lower jealousy over time.',
        ),
      ],
    ),
    LearningPath(
      title: 'Safer sex & testing, without the awkward',
      promise: 'The practical health layer of ENM, made normal and shame-free.',
      reads: [
        MicroRead(
          title: 'Testing 101',
          description:
              'What to ask for, how often, and what a "full panel" actually covers.',
        ),
        MicroRead(
          title: 'The results conversation',
          description:
              'Scripts for sharing your status and asking for a partner\'s, without it feeling like an interrogation.',
        ),
        MicroRead(
          title: 'Barriers, honestly',
          description:
              'Using condoms and dams consistently, and talking about it when enthusiasm dips.',
        ),
        MicroRead(
          title: 'Fluid bonding decisions',
          description:
              'What it means for the whole network, and how to make (or revisit) that agreement together.',
        ),
      ],
    ),
    LearningPath(
      title: 'Coming out as poly',
      promise:
          'Deciding who to tell, how, and when — at your pace, on your terms.',
      reads: [
        MicroRead(
          title: 'Who needs to know?',
          description:
              'Sorting the world into must-tell, safe-to-tell, and not-their-business.',
        ),
        MicroRead(
          title: 'The first conversation',
          description:
              'Framing polyamory for family and friends who may only know stereotypes.',
        ),
        MicroRead(
          title: 'Work, kids, and complications',
          description:
              'Custody fears, workplace realities, and what\'s actually true about the risks.',
        ),
        MicroRead(
          title: 'When it goes badly (and when it goes fine)',
          description:
              'Handling pushback, protecting your peace, and finding your people.',
        ),
      ],
    ),
    LearningPath(
      title: 'Long-distance connections',
      promise:
          'Keeping love vivid across miles — and orbits that don\'t align often.',
      reads: [
        MicroRead(
          title: 'Rhythms that work',
          description:
              'Setting communication patterns that nourish instead of draining: calls, texts, and space between.',
        ),
        MicroRead(
          title: 'Dates at a distance',
          description:
              'Shared activities that create real presence: movies, games, cooking the same meal, falling asleep on the phone.',
        ),
        MicroRead(
          title: 'Visits and comet time',
          description:
              'Planning time together that feels full rather than frantic, and re-entry gentleness after.',
        ),
        MicroRead(
          title: 'The in-between',
          description:
              'Managing loneliness, NRE imbalance, and local partners while a far-away love stays real.',
        ),
      ],
    ),
  ];

  static const List<BookRecommendation> books = [
    BookRecommendation(
      title: 'Polysecure',
      author: 'Jessica Fern',
      readThisIf:
          'you want to understand attachment styles and build emotional safety across multiple bonds',
      libraryUrl: 'https://www.overdrive.com/search?q=Polysecure',
      blurb:
          'The current gold standard on why we attach the way we do, and how to do it more securely.',
    ),
    BookRecommendation(
      title: 'The Ethical Slut',
      author: 'Dossie Easton & Janet W. Hardy',
      readThisIf:
          'you want the foundational classic: radical honesty, sex positivity, and joyful practicality about loving more than one person',
      libraryUrl: 'https://www.overdrive.com/search?q=The+Ethical+Slut',
    ),
    BookRecommendation(
      title: 'Love Beyond Monogamy',
      author: 'Brian G. Murphy',
      readThisIf:
          'you\'re seeking a queer, spiritually grounded, and practical perspective on expanding love',
      libraryUrl: 'https://www.overdrive.com/search?q=Love+Beyond+Monogamy',
    ),
    BookRecommendation(
      title: 'Opening Up',
      author: 'Tristan Taormino',
      readThisIf:
          'you want a hands-on guide to creating and sustaining open relationships, full of real couples\' arrangements and worksheets',
      libraryUrl: 'https://www.overdrive.com/search?q=Opening+Up+Taormino',
    ),
    BookRecommendation(
      title: 'Stepping Off the Relationship Escalator',
      author: 'Amy Gahran',
      readThisIf:
          'you want the wide map of unconventional relationship forms — and permission to design your own',
      // Not carried in the OverDrive catalog (verified 2026-10-27:
      // the exact-title search returns no results), so the library
      // action points at WorldCat holdings instead of an empty
      // OverDrive search.
      libraryUrl:
          'https://search.worldcat.org/search?q=Stepping+Off+the+Relationship+Escalator',
      libraryActionLabel: 'Find it at your library',
    ),
  ];
}
