//
//  Interest.swift
//  Scholar
//
//  The "For You" grid: six broad categories, each holding a set of specific
//  interest tags. Selecting either level feeds the ranker — a category turns
//  on everything beneath it, a tag turns on just itself.
//

import SwiftUI

nonisolated enum InterestCategory: String, CaseIterable, Identifiable, Codable, Sendable {
    case stem, humanities, society, business, lifestyle, general

    var id: String { rawValue }

    var title: String {
        switch self {
        case .stem:       return "STEM"
        case .humanities: return "Humanities"
        case .society:    return "Society"
        case .business:   return "Business"
        case .lifestyle:  return "Lifestyle"
        case .general:    return "General"
        }
    }

    var tint: Color {
        switch self {
        case .stem:       return Color(hex: 0x5AC8FA)
        case .humanities: return Color(hex: 0xFFB86B)
        case .society:    return Color(hex: 0xC98BFF)
        case .business:   return Color(hex: 0x4ADE80)
        case .lifestyle:  return Color(hex: 0xFF8FA3)
        case .general:    return Color(hex: 0x9AA4B2)
        }
    }

    var interests: [Interest] { Interest.all.filter { $0.category == self } }
}

nonisolated struct Interest: Identifiable, Hashable, Codable, Sendable {
    let id: String
    let name: String
    let category: InterestCategory
    let emoji: String
    /// Channels whose Shorts shelf is a good match for this interest.
    let channelIDs: [String]
    /// Full-text queries handed to the iTunes podcast directory.
    let podcastQueries: [String]
    /// Terms that only ever mean *this* subject. A document has to hit one of
    /// these before it can be tagged with the interest at all.
    ///
    /// The distinction exists because the obvious vocabulary of a subject is
    /// mostly shared: "memory", "neural", "learning" and "model" belong to
    /// Neuroscience, AI, Education and half of STEM at once, and scoring them
    /// flat is what filed a document about training on-device models under
    /// Neuroscience. Anchors are the terms with only one owner —
    /// "neurotransmitter", "hippocampus" — plus the multi-word phrases that
    /// disambiguate a shared word ("neural network" is AI, not the brain).
    let anchors: [String]
    /// Terms that corroborate an anchor but are far too common to stand on
    /// their own. Never enough to earn the tag by themselves.
    let keywords: [String]

    var channels: [EduChannel] { channelIDs.compactMap(ChannelCatalog.channel(id:)) }
    var tint: Color { category.tint }
}

extension Interest {
    /// Authoring rules for `anchors` and `keywords`, because the matcher reads
    /// them literally (see `KeywordExtractor.matchingInterests`):
    ///
    /// - Terms are matched on whole words, never substrings. "ai" no longer
    ///   fires on "training", and "gene" no longer fires on "general".
    /// - A term of six characters or more also matches its inflections
    ///   ("behaviour" → "behavioural"); anything shorter must match exactly.
    ///   Write stems at six characters or longer, or they will not stem.
    /// - The longest phrase covering a span of text wins it outright, so a
    ///   phrase here is how you take a shared word off another subject.
    nonisolated static let all: [Interest] = [
        // ── STEM ──────────────────────────────────────────────────────────
        Interest(id: "physics", name: "Physics", category: .stem, emoji: "⚛️",
                 channelIDs: [ChannelCatalog.minutePhysics.id, ChannelCatalog.veritasium.id,
                              ChannelCatalog.steveMould.id, ChannelCatalog.actionLab.id,
                              ChannelCatalog.kurzgesagt.id],
                 podcastQueries: ["physics", "quantum physics"],
                 anchors: ["physics", "quantum mechanic", "quantum entanglement", "relativity",
                           "thermodynamic", "electromagnet", "newtonian", "photon", "neutrino",
                           "kinetic energy", "potential energy", "wavelength", "superconduct",
                           "particle physics", "higgs", "string theory", "momentum", "entropy",
                           "speed of light", "wave function", "half life"],
                 keywords: ["gravity", "energy", "particle", "force", "mass", "velocity",
                            "friction", "magnet", "nuclear", "atom", "electron"]),

        Interest(id: "mathematics", name: "Mathematics", category: .stem, emoji: "📐",
                 channelIDs: [ChannelCatalog.threeBlueOneBrown.id, ChannelCatalog.numberphile.id],
                 podcastQueries: ["mathematics", "math"],
                 anchors: ["mathematic", "calculus", "algebra", "geometr", "theorem", "topolog",
                           "integral", "linear algebra", "probabilit", "trigonometr", "logarithm",
                           "polynomial", "prime number", "fourier", "differential equation",
                           "eigenvalue", "factorial", "modulo"],
                 keywords: ["math", "number", "proof", "equation", "matrix", "vector",
                            "derivative", "statistic", "coefficient"]),

        Interest(id: "chemistry", name: "Chemistry", category: .stem, emoji: "🧪",
                 channelIDs: [ChannelCatalog.nileRed.id, ChannelCatalog.periodicVideos.id,
                              ChannelCatalog.sciShow.id],
                 podcastQueries: ["chemistry"],
                 anchors: ["chemistry", "chemical reaction", "periodic table", "covalent",
                           "ionic bond", "stoichiometr", "titration", "catalyst", "reagent",
                           "electrolysis", "organic chemistry", "isotope", "valence", "oxidation",
                           "hydrocarbon", "molarity", "acid base", "distillation", "alkaline"],
                 keywords: ["element", "reaction", "acid", "compound", "bond", "solvent",
                            "molecule", "chemical", "polymer", "crystal"]),

        Interest(id: "space", name: "Space", category: .stem, emoji: "🪐",
                 channelIDs: [ChannelCatalog.nasa.id, ChannelCatalog.astrum.id,
                              ChannelCatalog.kurzgesagt.id],
                 podcastQueries: ["astronomy", "space exploration"],
                 anchors: ["astronom", "astrophysic", "galax", "black hole", "supernova", "nebula",
                           "exoplanet", "solar system", "spacecraft", "telescope", "asteroid",
                           "interstellar", "cosmolog", "light year", "milky way", "satellite",
                           "space station", "orbital", "meteorite"],
                 keywords: ["space", "planet", "star", "moon", "mars", "cosmic", "rocket",
                            "universe", "orbit", "nasa"]),

        Interest(id: "ai-tech", name: "AI & Tech", category: .stem, emoji: "🤖",
                 channelIDs: [ChannelCatalog.fireship.id, ChannelCatalog.veritasium.id],
                 podcastQueries: ["artificial intelligence", "software engineering"],
                 // The phrases here exist to win shared words back from other
                 // subjects: "neural network" from Neuroscience, "machine
                 // learning" and "training data" from Education, "language
                 // model" from Language.
                 anchors: ["artificial intelligence", "machine learning", "deep learning",
                           "neural network", "neural net", "language model", "training data",
                           "training run", "gradient descent", "backpropagation", "fine tuning",
                           "fine-tuning", "quantization", "quantisation", "transformer model",
                           "attention head", "learning rate", "overfitting", "convolution",
                           "tokenizer", "embedding", "dataset", "inference", "hyperparameter",
                           "pytorch", "tensorflow", "core ml", "coreml", "apple silicon",
                           "on-device", "on device", "software", "programming", "algorithm",
                           "compiler", "javascript", "python", "kubernetes", "cybersecurit",
                           "encryption", "open source", "source code", "database", "runtime",
                           "operating system", "semiconductor", "transistor", "computer science",
                           "cloud computing", "reinforcement learning", "supervised learning",
                           "computer vision", "natural language processing"],
                 keywords: ["ai", "llm", "gpu", "cpu", "model", "code", "compute", "tech",
                            "computer", "neural", "token", "memory", "chip", "silicon",
                            "latency", "benchmark", "parameter", "developer", "server"]),

        Interest(id: "engineering", name: "Engineering", category: .stem, emoji: "⚙️",
                 channelIDs: [ChannelCatalog.realEngineering.id, ChannelCatalog.markRober.id,
                              ChannelCatalog.actionLab.id],
                 podcastQueries: ["engineering"],
                 anchors: ["engineering", "aerodynamic", "hydraulic", "turbine", "combustion",
                           "load bearing", "torque", "suspension bridge", "jet engine", "robotic",
                           "actuator", "thermal expansion", "manufactur", "tensile", "bearing",
                           "gearbox", "circuit board", "structural"],
                 keywords: ["machine", "bridge", "aircraft", "mechanical", "motor", "gear",
                            "material", "friction", "prototype"]),

        Interest(id: "biology", name: "Biology", category: .stem, emoji: "🧬",
                 channelIDs: [ChannelCatalog.realScience.id, ChannelCatalog.beSmart.id,
                              ChannelCatalog.asapScience.id],
                 podcastQueries: ["biology"],
                 anchors: ["biolog", "cell membrane", "mitochond", "photosynth", "enzyme",
                           "ribosome", "chloroplast", "cellular respiration", "organism",
                           "prokaryot", "eukaryot", "homeostasis", "osmosis", "meiosis",
                           "mitosis", "protein synthesis", "amino acid", "cytoplasm",
                           "bacteria", "microbe", "metabolism", "nucleus"],
                 keywords: ["cell", "dna", "protein", "life", "species", "tissue", "membrane",
                            "molecule", "glucose", "virus"]),

        Interest(id: "medicine", name: "Medicine", category: .stem, emoji: "🩺",
                 channelIDs: [ChannelCatalog.osmosis.id, ChannelCatalog.zackDFilms.id,
                              ChannelCatalog.asapScience.id],
                 podcastQueries: ["medicine", "medical school"],
                 anchors: ["medicine", "medical", "anatom", "patholog", "cardiovascular",
                           "diagnosis", "diagnostic", "clinical", "pharmacolog", "antibiotic",
                           "immune system", "infection", "surgery", "surgical", "physiolog",
                           "carcinoma", "inflammation", "blood pressure", "vaccine", "syndrome",
                           "prescription", "artery", "hormone"],
                 keywords: ["disease", "body", "health", "doctor", "blood", "muscle",
                            "treatment", "patient", "symptom", "therapy"]),

        Interest(id: "genetics", name: "Genetics", category: .stem, emoji: "🧫",
                 channelIDs: [ChannelCatalog.osmosis.id, ChannelCatalog.realScience.id],
                 podcastQueries: ["genetics", "genomics"],
                 anchors: ["genetic", "genome", "crispr", "allele", "chromosome", "mutation",
                           "heredit", "genotype", "phenotype", "dna sequenc", "messenger rna",
                           "gene expression", "recombinant", "punnett", "epigenetic", "nucleotide"],
                 keywords: ["gene", "dna", "rna", "inherit", "trait", "genome"]),

        Interest(id: "zoology", name: "Zoology", category: .stem, emoji: "🦎",
                 channelIDs: [ChannelCatalog.tierZoo.id, ChannelCatalog.bbcEarth.id,
                              ChannelCatalog.natGeo.id],
                 podcastQueries: ["animals", "wildlife"],
                 anchors: ["zoolog", "mammal", "reptile", "amphibian", "predator", "carnivore",
                           "herbivore", "primate", "marsupial", "invertebrate", "camouflage",
                           "migration pattern", "nocturnal", "venom", "wildlife"],
                 keywords: ["animal", "species", "insect", "bird", "habitat", "hunt", "prey"]),

        Interest(id: "ecology", name: "Ecology", category: .stem, emoji: "🌱",
                 channelIDs: [ChannelCatalog.minuteEarth.id, ChannelCatalog.natGeo.id,
                              ChannelCatalog.bbcEarth.id],
                 podcastQueries: ["ecology", "climate"],
                 anchors: ["ecolog", "ecosystem", "biodiversit", "climate change", "greenhouse gas",
                           "deforestation", "carbon cycle", "food chain", "conservation",
                           "pollution", "renewable energy", "sustainab", "rainforest",
                           "global warming", "watershed", "fossil fuel"],
                 keywords: ["climate", "environment", "forest", "carbon", "earth", "habitat",
                            "emission", "wetland"]),

        Interest(id: "neuroscience", name: "Neuroscience", category: .stem, emoji: "🧠",
                 channelIDs: [ChannelCatalog.sciShow.id, ChannelCatalog.beSmart.id,
                              ChannelCatalog.osmosis.id],
                 podcastQueries: ["neuroscience", "the brain"],
                 // Deliberately biological. "neural", "memory" and "network"
                 // are not anchors here — they are the exact words a machine
                 // learning document is full of.
                 anchors: ["neuroscience", "neurolog", "neuron", "synapse", "synaptic",
                           "neurotransmitter", "dopamine", "serotonin", "hippocampus", "amygdala",
                           "cerebral cortex", "prefrontal cortex", "cerebellum", "axon",
                           "dendrite", "myelin", "neural circuit", "neural pathway",
                           "neuroplasticit", "grey matter", "gray matter", "brain"],
                 keywords: ["memory", "cognition", "cognitive", "consciousness", "nervous",
                            "perception", "reflex", "neural"]),

        // ── Humanities ────────────────────────────────────────────────────
        Interest(id: "history", name: "History", category: .humanities, emoji: "🏛️",
                 channelIDs: [ChannelCatalog.simpleHistory.id, ChannelCatalog.knowledgia.id,
                              ChannelCatalog.historyMatters.id],
                 podcastQueries: ["history"],
                 anchors: ["history", "historical", "empire", "dynast", "medieval", "roman empire",
                           "ancient rome", "world war", "monarch", "colonial", "renaissance",
                           "feudal", "civilisation", "civilization", "napoleon", "crusade",
                           "cold war", "industrial revolution", "the treaty", "reformation",
                           "antiquit", "century"],
                 keywords: ["war", "ancient", "roman", "republic", "senate", "battle",
                            "conquest", "king", "army", "revolution", "treaty"]),

        Interest(id: "philosophy", name: "Philosophy", category: .humanities, emoji: "💭",
                 channelIDs: [ChannelCatalog.schoolOfLife.id, ChannelCatalog.ted.id],
                 podcastQueries: ["philosophy"],
                 anchors: ["philosoph", "epistemolog", "metaphysic", "stoicism", "existential",
                           "utilitarian", "nihilis", "socrates", "plato", "aristotle", "nietzsche",
                           "free will", "moral philosophy", "dialectic", "ontolog", "determinism",
                           "categorical imperative"],
                 keywords: ["ethics", "ethical", "meaning", "moral", "truth", "virtue",
                            "argument", "reason"]),

        Interest(id: "language", name: "Language", category: .humanities, emoji: "🗣️",
                 channelIDs: [ChannelCatalog.langfocus.id, ChannelCatalog.tedEd.id],
                 podcastQueries: ["linguistics", "language learning"],
                 anchors: ["linguistic", "grammar", "phonetic", "phonolog", "etymolog",
                           "morpholog", "dialect", "alphabet", "conjugation", "vocabular",
                           "bilingual", "loanword", "proto-indo", "native speaker",
                           "language family", "verb tense"],
                 keywords: ["language", "word", "sentence", "verb", "noun", "speech",
                            "translation", "syntax", "semantic"]),

        Interest(id: "anthropology", name: "Anthropology", category: .humanities, emoji: "🗿",
                 channelIDs: [ChannelCatalog.langfocus.id, ChannelCatalog.knowledgia.id,
                              ChannelCatalog.tedEd.id],
                 podcastQueries: ["anthropology", "archaeology"],
                 anchors: ["anthropolog", "archaeolog", "archeolog", "ethnograph", "kinship",
                           "hunter-gatherer", "excavation", "indigenous", "folklore", "neolithic",
                           "paleolithic", "burial site", "artefact", "artifact", "shaman"],
                 keywords: ["culture", "cultural", "human", "tribe", "ritual", "ancestor",
                            "tradition", "myth"]),

        Interest(id: "geography", name: "Geography", category: .humanities, emoji: "🗺️",
                 channelIDs: [ChannelCatalog.geographyNow.id, ChannelCatalog.minuteEarth.id],
                 podcastQueries: ["geography"],
                 anchors: ["geograph", "topograph", "latitude", "longitude", "tectonic",
                           "peninsula", "archipelago", "cartograph", "population density",
                           "mountain range", "climate zone", "biome", "glacier", "monsoon",
                           "capital city"],
                 keywords: ["country", "border", "map", "city", "river", "continent",
                            "region", "terrain", "island"]),

        // ── Society ───────────────────────────────────────────────────────
        Interest(id: "psychology", name: "Psychology", category: .society, emoji: "🫀",
                 channelIDs: [ChannelCatalog.psych2Go.id, ChannelCatalog.schoolOfLife.id,
                              ChannelCatalog.sprouts.id],
                 podcastQueries: ["psychology"],
                 anchors: ["psycholog", "cognitive bias", "behaviour", "behavior", "personalit",
                           "anxiety", "depression", "psychotherap", "freud", "conditioning",
                           "self-esteem", "attachment style", "mental health", "empath",
                           "introvert", "extrovert", "coping mechanism", "stress response"],
                 keywords: ["emotion", "mind", "feeling", "trauma", "attention", "mood",
                            "therapy", "motivation"]),

        Interest(id: "politics", name: "Politics", category: .society, emoji: "🏳️",
                 channelIDs: [ChannelCatalog.knowledgia.id, ChannelCatalog.geographyNow.id,
                              ChannelCatalog.ted.id],
                 podcastQueries: ["politics explained"],
                 anchors: ["politic", "democrac", "election", "parliament", "constitution",
                           "legislation", "legislative", "referendum", "ideolog", "geopolitic",
                           "sovereignt", "diplomac", "authoritarian", "suffrage", "judiciar",
                           "foreign policy", "coalition"],
                 keywords: ["government", "policy", "law", "state", "vote", "party",
                            "power", "senate"]),

        Interest(id: "social-issues", name: "Social Issues", category: .society, emoji: "⚖️",
                 channelIDs: [ChannelCatalog.ted.id, ChannelCatalog.sprouts.id],
                 podcastQueries: ["social issues", "sociology"],
                 anchors: ["sociolog", "inequalit", "social justice", "poverty", "discriminat",
                           "human rights", "gentrification", "welfare", "activism", "demographic",
                           "civil rights", "social mobility", "marginalis", "marginaliz"],
                 keywords: ["society", "justice", "community", "rights", "social", "class",
                            "gender", "privilege"]),

        Interest(id: "education", name: "Education", category: .society, emoji: "🎓",
                 channelIDs: [ChannelCatalog.sprouts.id, ChannelCatalog.tedEd.id],
                 podcastQueries: ["education", "learning science"],
                 // "learning" alone is not an anchor: "machine learning" and
                 // "deep learning" are the commonest uses of the word in
                 // anything technical, and both belong to AI & Tech.
                 anchors: ["pedagog", "curriculum", "classroom", "standardised test",
                           "standardized test", "spaced repetition", "active recall",
                           "montessori", "literacy rate", "teaching method", "study skill",
                           "tutoring", "lesson plan", "learning science", "student engagement"],
                 keywords: ["education", "learning", "school", "study", "teaching",
                            "student", "lesson", "homework", "exam", "memory"]),

        // ── Business ──────────────────────────────────────────────────────
        Interest(id: "economics", name: "Economics", category: .business, emoji: "📈",
                 channelIDs: [ChannelCatalog.economicsExplained.id, ChannelCatalog.twoCents.id],
                 podcastQueries: ["economics"],
                 anchors: ["economic", "economy", "inflation", "recession", "monetary polic",
                           "fiscal", "supply and demand", "macroeconom", "microeconom",
                           "interest rate", "tariff", "unemployment", "central bank",
                           "trade deficit", "gross domestic product", "capitalis"],
                 keywords: ["gdp", "market", "trade", "price", "currency", "growth", "labour",
                            "labor", "export"]),

        Interest(id: "finance", name: "Personal Finance", category: .business, emoji: "💰",
                 channelIDs: [ChannelCatalog.twoCents.id, ChannelCatalog.economicsExplained.id],
                 podcastQueries: ["personal finance", "investing"],
                 anchors: ["personal finance", "compound interest", "index fund", "portfolio",
                           "mortgage", "retirement", "credit score", "dividend", "stock market",
                           "budgeting", "net worth", "insurance premium", "capital gain",
                           "emergency fund", "pension"],
                 keywords: ["money", "invest", "saving", "debt", "budget", "stock",
                            "income", "loan", "tax"]),

        // ── Lifestyle ─────────────────────────────────────────────────────
        Interest(id: "health", name: "Health & Fitness", category: .lifestyle, emoji: "🏃",
                 channelIDs: [ChannelCatalog.asapScience.id, ChannelCatalog.osmosis.id,
                              ChannelCatalog.sciShow.id],
                 podcastQueries: ["health", "nutrition science"],
                 anchors: ["nutrition", "calorie", "macronutrient", "strength training",
                           "sleep hygiene", "cardio", "hydration", "cholesterol", "aerobic",
                           "protein intake", "workout", "body mass index", "circadian",
                           "resistance training", "immune"],
                 keywords: ["health", "fitness", "sleep", "diet", "exercise", "muscle",
                            "weight", "energy", "metabolism"]),

        Interest(id: "productivity", name: "Productivity", category: .lifestyle, emoji: "⚡",
                 channelIDs: [ChannelCatalog.sprouts.id, ChannelCatalog.schoolOfLife.id,
                              ChannelCatalog.ted.id],
                 podcastQueries: ["productivity", "habits"],
                 anchors: ["productivit", "procrastinat", "time management", "deep work",
                           "habit formation", "goal setting", "pomodoro", "burnout",
                           "prioriti", "to-do list", "context switching", "accountabilit"],
                 keywords: ["habit", "focus", "motivation", "routine", "distraction",
                            "workflow", "discipline"]),

        // ── General ───────────────────────────────────────────────────────
        // The two generalist interests carry no anchors on purpose: nothing
        // should ever be *classified* as Curiosities. They exist as the
        // explicit fallback when the user has picked no interests at all.
        Interest(id: "curiosities", name: "Curiosities", category: .general, emoji: "🔮",
                 channelIDs: [ChannelCatalog.vsauce.id, ChannelCatalog.howStuffWorks.id,
                              ChannelCatalog.zackDFilms.id, ChannelCatalog.scienceABC.id],
                 podcastQueries: ["curiosity", "interesting facts"],
                 anchors: [],
                 keywords: ["why", "how", "weird", "strange", "fact", "surprising"]),

        Interest(id: "big-ideas", name: "Big Ideas", category: .general, emoji: "💡",
                 channelIDs: [ChannelCatalog.ted.id, ChannelCatalog.tedEd.id,
                              ChannelCatalog.kurzgesagt.id, ChannelCatalog.seeker.id],
                 podcastQueries: ["big ideas", "ted talks daily"],
                 anchors: [],
                 keywords: ["idea", "future", "theory", "innovation", "discovery", "breakthrough"])
    ]

    nonisolated static func find(_ id: String) -> Interest? { all.first { $0.id == id } }

    /// Default selection for a brand-new install, so the feed is never empty.
    nonisolated static let starterIDs: Set<String> = ["curiosities", "space", "history", "psychology", "big-ideas"]
}
