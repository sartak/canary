import Foundation

enum PredictionAction {
    case insert(String)
    case moveCursor(Int)  // positive = forward, negative = backward
    case maybePunctuating(Bool)
}

class PredictionService {
    private static let maxSuggestions = 20

    private static let corpus: [String] = [
        "the", "of", "and", "to", "in", "for", "is", "on", "that", "by",
        "this", "with", "you", "it", "not", "or", "be", "are", "from", "at",
        "as", "your", "all", "have", "new", "more", "an", "was", "we", "will",
        "home", "can", "us", "about", "if", "page", "my", "has", "search", "free",
        "but", "our", "one", "other", "do", "no", "information", "time", "they", "site",
        "he", "up", "may", "what", "which", "their", "news", "out", "use", "any",
        "there", "see", "only", "so", "his", "when", "contact", "here", "business", "who",
        "web", "also", "now", "help", "get", "view", "online", "first", "am", "been",
        "would", "how", "were", "me", "services", "some", "these", "click", "its", "like",
        "service", "than", "find", "price", "date", "back", "top", "people", "had", "list",
        "name", "just", "over", "state", "year", "day", "into", "email", "two", "health",
        "world", "re", "next", "used", "go", "work", "last", "most", "products", "music",
        "buy", "data", "make", "them", "should", "product", "system", "post", "her", "city",
        "add", "policy", "number", "such", "please", "available", "copyright", "support", "message", "after",
        "best", "software", "then", "good", "video", "well", "where", "info", "rights", "public",
        "books", "high", "school", "through", "each", "links", "she", "review", "years", "order",
        "very", "privacy", "book", "items", "company", "read", "group", "sex", "need", "many",
        "user", "said", "de", "does", "set", "under", "general", "research", "university", "mail",
        "full", "map", "reviews", "program", "life", "know", "games", "way", "days", "management",
        "part", "could", "great", "united", "hotel", "real", "item", "international", "center", "must",
        "store", "travel", "comments", "made", "development", "report", "off", "member", "details", "line",
        "terms", "before", "hotels", "did", "send", "right", "type", "because", "local", "those",
        "using", "results", "office", "education", "national", "car", "design", "take", "posted", "internet",
        "address", "community", "within", "states", "area", "want", "phone", "shipping", "reserved", "subject",
        "between", "forum", "family", "long", "based", "code", "show", "even", "black", "check",
        "special", "prices", "website", "index", "being", "women", "much", "sign", "file", "link",
        "open", "today", "technology", "south", "case", "project", "same", "pages", "version", "section",
        "own", "found", "sports", "house", "related", "security", "both", "county", "photo", "game",
        "members", "power", "while", "care", "network", "down", "computer", "systems", "three", "total",
        "place", "end", "following", "download", "him", "without", "per", "access", "think", "north",
        "resources", "current", "posts", "big", "media", "law", "control", "water", "history", "pictures",
        "size", "art", "personal", "since", "including", "guide", "shop", "directory", "board", "location",
        "change", "white", "text", "small", "rating", "rate", "government", "children", "during", "return",
        "students", "shopping", "account", "times", "sites", "level", "digital", "profile", "previous", "form",
        "events", "love", "old", "john", "main", "call", "hours", "image", "department", "title",
        "description", "non", "insurance", "another", "why", "shall", "property", "class", "still", "money",
        "quality", "every", "listing", "content", "country", "private", "little", "visit", "save", "tools",
        "low", "reply", "customer", "compare", "movies", "include", "college", "value", "article", "york",
        "man", "card", "jobs", "provide", "food", "source", "author", "different", "press", "learn",
        "sale", "around", "print", "course", "job", "canada", "process", "teen", "room", "stock",
        "training", "too", "credit", "point", "join", "science", "men", "categories", "advanced", "west",
        "sales", "look", "english", "left", "team", "estate", "box", "conditions", "select", "windows",
        "photos", "gay", "thread", "week", "category", "note", "live", "large", "gallery", "table",
        "register", "however", "november", "market", "library", "really", "action", "start", "series", "model",
        "features", "air", "industry", "plan", "human", "provided", "yes", "required", "second", "hot",
        "accessories", "cost", "movie", "forums", "march", "la", "better", "say", "questions", "yahoo",
        "going", "medical", "test", "friend", "come", "server", "study", "application", "cart", "staff",
        "articles", "san", "feedback", "again", "play", "looking", "issues", "never", "users", "complete",
        "street", "topic", "comment", "financial", "things", "working", "against", "standard", "tax", "person",
        "below", "mobile", "less", "got", "blog", "party", "payment", "equipment", "login", "student",
        "let", "programs", "offers", "legal", "above", "recent", "park", "stores", "side", "act",
        "problem", "red", "give", "memory", "performance", "social", "august", "quote", "language", "story",
        "sell", "options", "experience", "rates", "create", "key", "body", "young", "important", "field",
        "few", "east", "paper", "single", "age", "activities", "club", "example", "girls", "additional",
        "password", "latest", "something", "road", "gift", "question", "changes", "night", "hard", "texas",
        "pay", "four", "poker", "status", "browse", "issue", "range", "building", "seller", "court",
        "always", "result", "audio", "light", "write", "war", "offer", "blue", "groups", "al",
        "easy", "given", "files", "event", "release", "analysis", "request", "fax", "china", "making",
        "picture", "needs", "possible", "might", "professional", "yet", "month", "major", "star", "areas",
        "future", "space", "committee", "hand", "sun", "cards", "problems", "meeting", "become", "interest",
        "id", "child", "keep", "enter", "porn", "share", "similar", "garden", "schools", "million",
        "added", "reference", "companies", "listed", "baby", "learning", "energy", "run", "delivery", "net",
        "popular", "term", "film", "stories", "put", "computers", "journal", "reports", "try", "welcome",
        "central", "images", "president", "notice", "god", "original", "head", "radio", "until", "cell",
        "color", "self", "council", "away", "includes", "track", "discussion", "archive", "once", "others",
        "entertainment", "agreement", "format", "least", "society", "months", "log", "safety", "friends", "sure",
        "trade", "edition", "cars", "messages", "marketing", "tell", "further", "updated", "association", "able",
        "having", "provides", "fun", "already", "green", "studies", "close", "common", "drive", "specific",
        "several", "gold", "living", "collection", "called", "short", "arts", "lot", "ask", "display",
        "limited", "powered", "solutions", "means", "director", "daily", "beach", "past", "natural", "whether",
        "due", "et", "electronics", "five", "upon", "period", "planning", "database", "says", "official",
        "weather", "mar", "land", "average", "done", "technical", "window", "pro", "region", "island",
        "record", "direct", "conference", "environment", "records", "st", "district", "calendar", "costs", "style",
        "front", "statement", "update", "parts", "ever", "downloads", "early", "miles", "sound", "resource",
        "present", "applications", "either", "ago", "document", "works", "material", "bill", "written", "talk",
        "federal", "hosting", "rules", "final", "adult", "tickets", "thing", "centre", "requirements", "via",
        "cheap", "nude", "kids", "finance", "true", "minutes", "else", "mark", "third", "rock",
        "gifts", "reading", "topics", "bad", "individual", "tips", "plus", "auto", "cover", "usually",
        "edit", "together", "videos", "percent", "fast", "function", "fact", "unit", "getting", "global",
        "tech", "meet", "far", "economic", "en", "player", "projects", "lyrics", "often", "subscribe",
        "submit", "amount", "watch", "included", "feel", "though", "bank", "risk", "thanks", "everything",
        "deals", "various", "words", "linux", "production", "commercial", "james", "weight", "town", "heart",
        "advertising", "received", "choose", "treatment", "newsletter", "archives", "points", "knowledge", "magazine", "error",
        "camera", "jun", "girl", "currently", "construction", "toys", "registered", "clear", "golf", "receive",
        "domain", "methods", "chapter", "makes", "protection", "policies", "loan", "wide", "beauty", "manager",
        "india", "position", "taken", "sort", "listings", "models", "michael", "known", "half", "cases",
        "step", "engineering", "simple", "quick", "none", "wireless", "license", "paul", "lake", "whole",
        "annual", "published", "later", "basic", "shows", "corporate", "google", "church", "method", "purchase",
        "customers", "active", "response", "practice", "hardware", "figure", "materials", "fire", "holiday", "chat",
        "enough", "designed", "along", "among", "death", "writing", "speed", "countries", "loss", "face",
        "brand", "discount", "higher", "effects", "created", "remember", "standards", "oil", "bit", "yellow",
        "political", "increase", "advertise", "kingdom", "base", "near", "environmental", "thought", "stuff", "french",
        "storage", "oh", "japan", "doing", "loans", "shoes", "entry", "stay", "nature", "orders",
        "availability", "summary", "turn", "mean", "growth", "notes", "agency", "king", "activity", "copy",
        "although", "drug", "pics", "western", "income", "force", "cash", "employment", "overall", "bay",
        "river", "commission", "ad", "package", "contents", "seen", "players", "engine", "port", "album",
        "regional", "stop", "supplies", "started", "administration", "bar", "institute", "views", "plans", "double",
        "dog", "build", "screen", "exchange", "types", "soon", "sponsored", "lines", "electronic", "continue",
        "across", "benefits", "needed", "season", "apply", "someone", "held", "ny", "anything", "printer",
        "condition", "effective", "believe", "organization", "effect", "asked", "mind", "selection", "casino", "lost",
        "tour", "menu", "volume", "cross", "anyone", "mortgage", "hope", "silver", "corporation", "wish",
        "inside", "solution", "mature", "role", "rather", "weeks", "addition", "came", "supply", "nothing",
        "certain", "executive", "running", "lower", "necessary", "union", "jewelry", "according", "clothing", "mon",
        "particular", "fine", "names", "homepage", "hour", "gas", "skills", "six", "bush", "islands",
        "advice", "career", "military", "rental", "decision", "leave", "teens", "pre", "huge", "sat",
        "woman", "facilities", "zip", "bid", "kind", "sellers", "middle", "move", "cable", "opportunities",
        "taking", "values", "division", "coming", "object", "lesbian", "appropriate", "machine", "logo", "length",
        "actually", "nice", "score", "statistics", "client", "returns", "capital", "follow", "sample", "investment",
        "sent", "shown", "culture", "band", "flash", "lead", "choice", "went", "starting", "registration",
        "courses", "consumer", "hi", "airport", "foreign", "artist", "outside", "furniture", "levels", "channel",
        "letter", "mode", "phones", "ideas", "structure", "fund", "summer", "allow", "degree", "contract",
        "button", "releases", "wed", "homes", "super", "male", "matter", "custom", "virginia", "almost",
        "took", "located", "multiple", "distribution", "editor", "inn", "industrial", "cause", "potential", "song",
        "los", "focus", "late", "fall", "featured", "idea", "rooms", "female", "responsible", "communications",
        "win", "associated", "primary", "cancer", "numbers", "reason", "tool", "browser", "spring", "foundation",
        "answer", "voice", "friendly", "schedule", "documents", "communication", "purpose", "feature", "bed", "comes",
        "police", "everyone", "independent", "approach", "cameras", "brown", "physical", "operating", "hill", "maps",
        "medicine", "deal", "hold", "ratings", "forms", "glass", "happy", "smith", "wanted", "developed",
        "thank", "safe", "unique", "survey", "prior", "telephone", "sport", "ready", "feed", "animal",
        "sources", "population", "pa", "regular", "secure", "navigation", "operations", "therefore", "ass", "simply",
        "evidence", "station", "christian", "round", "favorite", "understand", "option", "master", "valley", "recently",
        "probably", "rentals", "sea", "built", "publications", "blood", "cut", "worldwide", "improve", "connection",
        "publisher", "hall", "larger", "anti", "networks", "earth", "parents", "impact", "transfer", "introduction",
        "kitchen", "strong", "tel", "wedding", "properties", "hospital", "ground", "overview", "ship", "accommodation",
        "owners", "disease", "excellent", "paid", "perfect", "hair", "opportunity", "kit", "classic", "basis",
        "command", "cities", "william", "express", "anal", "award", "distance", "tree", "peter", "assessment",
        "ensure", "thus", "wall", "involved", "el", "extra", "especially", "interface", "pussy", "partners",
        "budget", "rated", "guides", "success", "maximum", "ma", "operation", "existing", "quite", "selected",
        "boy", "amazon", "patients", "restaurants", "beautiful", "warning", "wine", "locations", "horse", "vote",
        "forward", "flowers", "stars", "significant", "lists", "technologies", "owner", "retail", "animals", "useful",
        "directly", "manufacturer", "ways", "est", "son", "providing", "rule", "mac", "housing", "takes",
        "bring", "catalog", "searches", "max", "trying", "mother", "authority", "considered", "told", "traffic",
        "programme", "joined", "input", "strategy", "feet", "agent", "valid", "bin", "modern", "senior",
        "sexy", "teaching", "door", "grand", "testing", "trial", "charge", "units", "instead", "cool",
        "normal", "wrote", "enterprise", "ships", "entire", "educational", "leading", "metal", "positive", "fitness",
        "chinese", "opinion", "football", "abstract", "uses", "output", "funds", "greater", "likely", "develop",
        "employees", "artists", "alternative", "processing", "responsibility", "resolution", "java", "guest", "seems", "publication",
        "pass", "relations", "trust", "van", "contains", "session", "photography", "republic", "fees", "components",
        "vacation", "century", "academic", "assistance", "completed", "skin", "graphics", "ads", "mary", "expected",
        "ring", "grade", "dating", "pacific", "mountain", "organizations", "pop", "filter", "mailing", "vehicle",
        "longer", "consider", "northern", "behind", "panel", "floor", "german", "buying", "match", "proposed",
        "default", "require", "boys", "outdoor", "deep", "morning", "otherwise", "allows", "rest", "protein",
        "plant", "reported", "hit", "transportation", "mm", "pool", "mini", "politics", "partner", "disclaimer",
        "authors", "boards", "faculty", "parties", "fish", "membership", "mission", "eye", "string", "sense",
        "modified", "pack", "released", "stage", "internal", "goods", "recommended", "born", "unless", "detailed",
        "race", "approved", "background", "target", "except", "character", "maintenance", "ability", "maybe", "functions",
        "ed", "moving", "brands", "places", "pretty", "trademarks", "spain", "southern", "yourself", "winter",
        "rape", "battery", "youth", "pressure", "submitted", "boston", "incest", "debt", "keywords", "medium",
        "television", "interested", "core", "break", "purposes", "throughout", "sets", "dance", "wood", "itself",
        "defined", "papers", "playing", "awards", "fee", "studio", "reader", "virtual", "device", "established",
        "answers", "rent", "las", "remote", "dark", "programming", "external", "apple", "regarding", "instructions",
        "offered", "theory", "enjoy", "remove", "aid", "surface", "minimum", "visual", "host", "variety",
        "teachers", "martin", "manual", "block", "subjects", "agents", "increased", "repair", "fair", "civil",
        "steel", "understanding", "songs", "fixed", "wrong", "beginning", "hands", "associates", "finally", "updates",
        "desktop", "classes", "paris", "gets", "sector", "capacity", "requires", "jersey", "un", "fat",
        "fully", "father", "electric", "saw", "instruments", "quotes", "officer", "driver", "businesses", "dead",
        "respect", "unknown", "specified", "restaurant", "mike", "trip", "pst", "worth", "mi", "procedures",
        "poor", "teacher", "eyes", "relationship", "workers", "farm", "fucking", "peace", "traditional", "campus",
        "tom", "showing", "creative", "coast", "benefit", "progress", "funding", "devices", "lord", "grant",
        "sub", "agree", "fiction", "hear", "sometimes", "watches", "careers", "beyond", "goes", "families",
        "led", "museum", "themselves", "fan", "transport", "interesting", "blogs", "wife", "evaluation", "accepted",
        "former", "implementation", "ten", "hits", "zone", "complex", "cat", "galleries", "references", "die",
        "presented", "jack", "flat", "flow", "agencies", "literature", "respective", "parent", "michigan", "setting",
        "scale", "stand", "economy", "highest", "helpful", "monthly", "critical", "frame", "musical", "definition",
        "secretary", "networking", "path", "employee", "chief", "gives", "bottom", "magazines", "packages", "detail",
        "laws", "changed", "pet", "heard", "begin", "individuals", "colorado", "royal", "clean", "switch",
        "largest", "guy", "titles", "relevant", "guidelines", "justice", "connect", "bible", "dev", "cup",
        "basket", "applied", "weekly", "vol", "installation", "described", "demand", "suite", "vegas", "na",
        "square", "attention", "advance", "skip", "diet", "army", "auction", "gear", "lee", "os",
        "difference", "allowed", "correct", "nation", "selling", "lots", "piece", "sheet", "firm", "seven",
        "older", "regulations", "elements", "species", "jump", "cells", "module", "resort", "facility", "random",
        "pricing", "certificate", "minister", "motion", "looks", "fashion", "directions", "visitors", "documentation", "monitor",
        "trading", "forest", "calls", "whose", "coverage", "couple", "giving", "chance", "vision", "ball",
        "ending", "clients", "actions", "listen", "discuss", "accept", "automotive", "naked", "goal", "successful",
        "sold", "wind", "communities", "clinical", "situation", "sciences", "markets", "lowest", "highly", "publishing",
        "appear", "emergency", "developing", "lives", "currency", "leather", "determine", "milf", "temperature", "palm",
        "announcements", "patient", "actual", "historical", "stone", "bob", "commerce", "ringtones", "perhaps", "persons",
        "difficult", "scientific", "satellite", "fit", "tests", "village", "accounts", "amateur", "ex", "met",
        "pain", "particularly", "factors", "coffee", "settings", "cum", "buyer", "cultural", "easily", "oral",
        "ford", "poster", "edge", "functional", "root", "closed", "holidays", "ice", "pink", "balance",
        "monitoring", "graduate", "replies", "shot", "architecture", "initial", "label", "thinking", "sec", "recommend",
        "canon", "hardcore", "league", "waste", "minute", "bus", "provider", "optional", "dictionary", "cold",
        "accounting", "manufacturing", "sections", "chair", "fishing", "effort", "phase", "fields", "bag", "fantasy",
        "po", "letters", "motor", "professor", "context", "install", "shirt", "apparel", "generally", "continued",
        "foot", "mass", "crime", "count", "breast", "techniques", "johnson", "quickly", "dollars", "websites",
        "religion", "claim", "driving", "permission", "surgery", "patch", "heat", "wild", "measures", "generation",
        "miss", "chemical", "doctor", "task", "reduce", "brought", "himself", "nor", "component", "enable",
        "exercise", "bug", "mid", "guarantee", "leader", "diamond", "processes", "soft", "servers", "alone",
        "meetings", "seconds", "jones", "keyword", "interests", "flight", "congress", "fuel", "username", "walk",
        "fuck", "produced", "paperback", "classifieds", "wait", "supported", "pocket", "saint", "rose", "freedom",
        "argument", "competition", "creating", "drugs", "joint", "premium", "providers", "fresh", "characters", "attorney",
        "upgrade", "di", "factor", "growing", "thousands", "stream", "apartments", "pick", "hearing", "eastern",
        "auctions", "therapy", "entries", "dates", "generated", "signed", "upper", "administrative", "serious", "prime",
        "limit", "began", "louis", "steps", "errors", "shops", "bondage", "del", "efforts", "informed",
        "thoughts", "creek", "worked", "quantity", "urban", "practices", "sorted", "reporting", "essential", "myself",
        "tours", "platform", "load", "affiliate", "labor", "immediately", "admin", "nursing", "defense", "machines",
        "designated", "tags", "heavy", "covered", "recovery", "joe", "guys", "integrated", "configuration", "cock",
        "merchant", "comprehensive", "expert", "universal", "protect", "drop", "solid", "presentation", "languages", "became",
        "orange", "compliance", "vehicles", "prevent", "theme", "rich", "campaign", "marine", "improvement", "guitar",
        "finding", "examples", "saying", "spirit", "ar", "claims", "porno", "challenge", "acceptance", "strategies",
        "mo", "seem", "affairs", "touch", "intended", "towards", "goals", "hire", "election", "suggest",
        "branch", "charges", "serve", "affiliates", "reasons", "magic", "mount", "smart", "talking", "gave",
        "ones", "multimedia", "tits", "avoid", "certified", "manage", "corner", "rank", "computing", "element",
        "birth", "virus", "abuse", "interactive", "requests", "separate", "quarter", "procedure", "leadership", "tables",
        "define", "racing", "religious", "facts", "breakfast", "column", "plants", "faith", "chain", "developer",
        "identify", "avenue", "missing", "died", "approximately", "domestic", "recommendations", "moved", "reach", "comparison",
        "mental", "viewed", "moment", "extended", "sequence", "inch", "attack", "sorry", "centers", "opening",
        "damage", "lab", "reserve", "recipes", "gamma", "plastic", "produce", "snow", "placed", "truth",
        "counter", "failure", "follows", "weekend", "dollar", "camp", "automatically", "films", "bridge", "native",
        "fill", "williams", "movement", "printing", "baseball", "owned", "approval", "draft", "chart", "played",
        "contacts", "jesus", "readers", "clubs", "equal", "adventure", "matching", "offering", "shirts", "profit",
        "leaders", "posters", "institutions", "assistant", "variable", "ave", "advertisement", "expect", "parking", "headlines",
        "yesterday", "compared", "determined", "wholesale", "workshop", "russia", "gone", "codes", "kinds", "extension",
        "statements", "golden", "completely", "teams", "fort", "lighting", "senate", "forces", "funny", "brother",
        "gene", "turned", "portable", "tried", "electrical", "applicable", "disc", "returned", "pattern", "boat",
        "named", "theatre", "laser", "earlier", "manufacturers", "sponsor", "classical", "icon", "warranty", "dedicated",
        "direction", "harry", "basketball", "objects", "ends", "delete", "evening", "assembly", "nuclear", "taxes",
        "mouse", "signal", "criminal", "issued", "brain", "sexual", "powerful", "dream", "obtained", "false",
        "da", "cast", "flower", "felt", "personnel", "passed", "supplied", "identified", "falls", "pic",
        "soul", "aids", "opinions", "promote", "stated", "stats", "professionals", "appears", "carry", "flag",
        "decided", "covers", "em", "advantage", "hello", "designs", "maintain", "tourism", "priority", "newsletters",
        "adults", "clips", "savings", "graphic", "atom", "payments", "estimated", "binding", "brief", "ended",
        "winning", "eight", "anonymous", "iron", "straight", "script", "served", "wants", "miscellaneous", "prepared",
        "void", "dining", "alert", "integration", "tag", "interview", "mix", "framework", "disk", "installed",
        "queen", "credits", "clearly", "fix", "handle", "sweet", "desk", "criteria", "hong", "vice",
        "associate", "ne", "truck", "behavior", "enlarge", "ray", "frequently", "revenue", "measure", "changing",
        "votes", "duty", "looked", "discussions", "bear", "gain", "festival", "laboratory", "ocean", "flights",
        "experts", "signs", "lack", "depth", "whatever", "logged", "laptop", "vintage", "train", "exactly",
        "dry", "explore", "spa", "concept", "nearly", "eligible", "checkout", "reality", "forgot", "handling",
        "origin", "knew", "gaming", "feeds", "billion", "destination", "faster", "intelligence", "bought", "con",
        "ups", "nations", "route", "followed", "specifications", "broken", "frank", "alaska", "zoom", "blow",
        "battle", "residential", "anime", "speak", "decisions", "industries", "protocol", "query", "clip", "partnership",
        "editorial", "expression", "es", "equity", "provisions", "speech", "wire", "principles", "suggestions", "rural",
        "shared", "sounds", "replacement", "tape", "strategic", "judge", "spam", "economics", "acid", "bytes",
        "cent", "forced", "compatible", "fight", "apartment", "height", "null", "zero", "speaker", "filed",
        "obtain", "consulting", "recreation", "offices", "designer", "remain", "managed", "failed", "marriage", "roll",
        "banks", "participants", "secret", "bath", "aa", "kelly", "leads", "negative", "favorites", "theater",
        "springs", "var", "perform", "healthy", "translation", "estimates", "font", "assets", "injury", "joseph",
        "ministry", "drivers", "lawyer", "figures", "married", "protected", "proposal", "sharing", "portal", "waiting",
        "birthday", "beta", "fail", "gratis", "banking", "officials", "toward", "won", "slightly", "assist",
        "conduct", "contained", "lingerie", "shemale", "legislation", "calling", "parameters", "jazz", "serving", "bags",
        "profiles", "comics", "matters", "houses", "doc", "postal", "relationships", "wear", "controls", "breaking",
        "combined", "ultimate", "wales", "representative", "frequency", "introduced", "minor", "finish", "departments", "residents",
        "noted", "displayed", "mom", "reduced", "physics", "rare", "spent", "performed", "extreme", "samples",
        "bars", "reviewed", "row", "forecast", "removed", "helps", "singles", "administrator", "cycle", "amounts",
        "contain", "accuracy", "dual", "rise", "sleep", "bird", "pharmacy", "brazil", "creation", "static",
        "scene", "hunter", "addresses", "lady", "crystal", "famous", "writer", "chairman", "violence", "fans",
        "speakers", "drink", "academy", "dynamic", "gender", "eat", "permanent", "agriculture", "dell", "cleaning",
        "constitutes", "portfolio", "practical", "delivered", "collectibles", "infrastructure", "exclusive", "seat", "concerns", "colour",
        "vendor", "originally", "intel", "utilities", "philosophy", "regulation", "officers", "reduction", "aim", "bids",
        "referred", "supports", "nutrition", "recording", "regions", "junior", "toll", "les", "cape", "ann",
        "rings", "meaning", "tip", "secondary", "wonderful", "mine", "ladies", "henry", "ticket", "announced",
        "guess", "agreed", "prevention", "whom", "ski", "soccer", "math", "import", "posting", "presence",
        "instant", "mentioned", "automatic", "healthcare", "viewing", "maintained", "ch", "increasing", "majority", "connected",
        "dan", "dogs", "directors", "aspects", "ahead", "moon", "participation", "scheme", "utility", "preview",
        "fly", "manner", "matrix", "containing", "combination", "devel", "amendment", "despite", "strength", "guaranteed",
        "turkey", "libraries", "proper", "distributed", "degrees", "enterprises", "delta", "fear", "seeking", "inches",
        "phoenix", "convention", "shares", "principal", "daughter", "standing", "voyeur", "comfort", "colors", "wars",
        "cisco", "ordering", "kept", "alpha", "appeal", "cruise", "bonus", "certification", "previously", "hey",
        "bookmark", "buildings", "specials", "beat", "household", "batteries", "adobe", "smoking", "becomes", "drives",
        "arms", "tea", "improved", "trees", "achieve", "positions", "dress", "subscription", "dealer", "contemporary",
        "sky", "nearby", "rom", "carried", "happen", "exposure", "hide", "permalink", "signature", "gambling",
        "refer", "miller", "provision", "outdoors", "clothes", "caused", "luxury", "babes", "frames", "certainly",
        "indeed", "newspaper", "toy", "circuit", "layer", "printed", "slow", "removal", "easier", "liability",
        "trademark", "hip", "printers", "nine", "adding", "mostly", "eric", "spot", "prints", "spend",
        "factory", "interior", "revised", "grow", "optical", "promotion", "relative", "amazing", "clock", "dot",
        "identity", "suites", "conversion", "feeling", "hidden", "reasonable", "victoria", "serial", "relief", "revision",
        "broadband", "influence", "ratio", "importance", "rain", "onto", "planet", "webmaster", "copies", "recipe",
        "permit", "seeing", "proof", "diff", "tennis", "bass", "prescription", "bedroom", "empty", "instance",
        "hole", "pets", "ride", "licensed", "specifically", "bureau", "represent", "conservation", "pair", "ideal",
        "specs", "recorded", "don", "pieces", "finished", "parks", "dinner", "lawyers", "stress", "cream",
        "runs", "trends", "yeah", "discover", "patterns", "boxes", "hills", "fourth", "advisor", "marketplace",
        "evil", "aware", "shape", "evolution", "certificates", "objectives", "stations", "suggested", "op", "remains",
        "greatest", "firms", "concerned", "euro", "operator", "structures", "generic", "encyclopedia", "usage", "cap",
        "ink", "charts", "continuing", "mixed", "census", "interracial", "peak", "competitive", "exist", "wheel",
        "transit", "dick", "suppliers", "salt", "compact", "poetry", "lights", "tracking", "angel", "bell",
        "keeping", "preparation", "attempt", "receiving", "matches", "accordance", "width", "noise", "engines", "forget",
        "array", "discussed", "accurate", "climate", "reservations", "pin", "alcohol", "greek", "instruction", "managing",
        "annotation", "sister", "raw", "differences", "walking", "explain", "smaller", "newest", "establish", "gnu",
        "happened", "expressed", "jeff", "extent", "sharp", "lesbians", "ben", "lane", "paragraph", "kill",
        "mathematics", "compensation", "export", "managers", "aircraft", "modules", "conflict", "conducted", "versions", "employer",
        "occur", "percentage", "knows", "describe", "concern", "backup", "requested", "citizens", "heritage", "personals",
        "immediate", "holding", "trouble", "spread", "coach", "agricultural", "expand", "supporting", "audience", "assigned",
        "jordan", "collections", "ages", "participate", "plug", "specialist", "cook", "affect", "virgin", "experienced",
        "investigation", "raised", "hat", "institution", "directed", "dealers", "searching", "sporting", "helping", "affected",
        "lib", "bike", "totally", "plate", "expenses", "indicate", "blonde", "ab", "proceedings", "favourite",
        "transmission", "characteristics", "lose", "organic", "seek", "experiences", "albums", "cheats", "extremely", "contracts",
        "guests", "hosted", "diseases", "concerning", "developers", "equivalent", "chemistry", "tony", "neighborhood", "kits",
        "variables", "agenda", "anyway", "continues", "tracks", "advisory", "cam", "curriculum", "logic", "template",
        "prince", "circle", "soil", "grants", "anywhere", "psychology", "responses", "wet", "circumstances", "investor",
        "identification", "ram", "leaving", "wildlife", "appliances", "matt", "elementary", "cooking", "speaking", "sponsors",
        "fox", "unlimited", "respond", "sizes", "plain", "exit", "entered", "arm", "keys", "launch",
        "wave", "checking", "costa", "printable", "holy", "acts", "guidance", "mesh", "trail", "enforcement",
        "symbol", "crafts", "highway", "buddy", "hardcover", "observed", "dean", "setup", "poll", "booking",
        "glossary", "fiscal", "celebrity", "styles", "filled", "bond", "channels", "appendix", "notify", "blues",
        "chocolate", "pub", "portion", "scope", "supplier", "cables", "cotton", "controlled", "requirement", "authorities",
        "biology", "dental", "killed", "border", "ancient", "debate", "representatives", "starts", "pregnancy", "causes",
        "biography", "leisure", "attractions", "learned", "transactions", "notebook", "explorer", "historic", "attached", "opened",
        "husband", "disabled", "authorized", "crazy", "upcoming", "concert", "retirement", "scores", "financing", "efficiency",
        "comedy", "adopted", "efficient", "weblog", "linear", "commitment", "specialty", "bears", "jean", "hop",
        "carrier", "edited", "constant", "visa", "mouth", "meter", "linked", "portland", "interviews", "concepts",
        "gun", "reflect", "pure", "deliver", "wonder", "hell", "lessons", "fruit", "begins", "qualified",
        "reform", "lens", "alerts", "treated", "discovery", "draw", "classified", "relating", "assume", "confidence",
        "alliance", "confirm", "warm", "neither", "lewis", "offline", "leaves", "engineer", "lifestyle", "consistent",
        "replace", "clearance", "connections", "inventory", "converter", "suck", "organisation", "babe", "checks", "reached",
        "becoming", "blowjob", "safari", "objective", "indicated", "sugar", "crew", "legs", "sam", "stick",
        "securities", "relation", "enabled", "genre", "slide", "volunteer", "tested", "rear", "democratic", "enhance",
        "exact", "bound", "parameter", "adapter", "processor", "node", "formal", "dimensions", "contribute", "lock",
        "hockey", "storm", "micro", "colleges", "laptops", "mile", "showed", "challenges", "editors", "threads",
        "bowl", "supreme", "brothers", "recognition", "presents", "ref", "tank", "submission", "dolls", "estimate",
        "encourage", "navy", "kid", "regulatory", "inspection", "consumers", "cancel", "limits", "territory", "transaction",
        "manchester", "weapons", "paint", "delay", "pilot", "outlet", "contributions", "continuous", "resulting", "initiative",
        "novel", "pan", "execution", "disability", "increases", "ultra", "winner", "contractor", "episode", "examination",
        "potter", "dish", "plays", "bulletin", "indicates", "modify", "oxford", "truly", "painting", "committed",
        "extensive", "affordable", "universe", "candidate", "databases", "patent", "slot", "outstanding", "ha", "eating",
        "perspective", "planned", "watching", "lodge", "messenger", "mirror", "tournament", "consideration", "discounts", "sterling",
        "sessions", "kernel", "boobs", "stocks", "buyers", "journals", "gray", "catalogue", "ea", "charged",
        "broad", "chosen", "demo", "greece", "swiss", "labour", "hate", "terminal", "publishers", "nights",
        "behalf", "liquid", "rice", "loop", "salary", "reservation", "foods", "gourmet", "guard", "properly",
        "orleans", "saving", "remaining", "empire", "resume", "twenty", "newly", "raise", "prepare", "avatar",
        "depending", "illegal", "expansion", "vary", "hundreds", "helped", "premier", "tomorrow", "purchased", "milk",
        "decide", "consent", "drama", "visiting", "performing", "downtown", "keyboard", "contest", "collected", "bands",
        "boot", "suitable", "absolutely", "millions", "lunch", "dildo", "audit", "push", "chamber", "guinea",
        "findings", "muscle", "featuring", "iso", "implement", "clicking", "scheduled", "polls", "typical", "tower",
        "yours", "sum", "calculator", "significantly", "chicken", "temporary", "attend", "shower", "alan", "sending",
        "tonight", "dear", "sufficient", "shell", "province", "catholic", "oak", "vat", "awareness", "governor",
        "beer", "seemed", "contribution", "measurement", "swimming", "spyware", "formula", "constitution", "packaging", "solar",
        "catch", "jane", "reliable", "consultation", "northwest", "sir", "doubt", "earn", "finder", "unable",
        "periods", "classroom", "tasks", "democracy", "attacks", "wallpaper", "merchandise", "resistance", "doors", "symptoms",
        "resorts", "biggest", "memorial", "visitor", "twin", "forth", "insert", "gateway", "ky", "alumni",
        "drawing", "candidates", "charlotte", "ordered", "biological", "fighting", "transition", "happens", "preferences", "spy",
        "romance", "instrument", "split", "themes", "powers", "heaven", "bits", "pregnant", "twice", "classification",
        "focused", "physician", "bargain", "cellular", "asking", "blocks", "normally", "lo", "spiritual", "hunting",
        "diabetes", "suit", "shift", "chip", "res", "sit", "bodies", "photographs", "cutting", "wow",
        "writers", "marks", "flexible", "loved", "favourites", "mapping", "numerous", "relatively", "birds", "satisfaction",
        "represents", "char", "indexed", "superior", "preferred", "saved", "paying", "cartoon", "shots", "intellectual",
        "granted", "choices", "carbon", "spending", "comfortable", "magnetic", "interaction", "listening", "effectively", "registry",
        "crisis", "outlook", "massive", "employed", "bright", "treat", "header", "poverty", "formed", "piano",
        "echo", "grid", "sheets", "patrick", "experimental", "revolution", "consolidation", "displays", "plasma", "allowing",
        "earnings", "voip", "mystery", "landscape", "dependent", "mechanical", "journey", "bidding", "consultants", "risks",
        "banner", "applicant", "charter", "fig", "cooperation", "counties", "acquisition", "ports", "implemented", "directories",
        "recognized", "dreams", "blogger", "notification", "licensing", "stands", "teach", "occurred", "textbooks", "rapid",
        "pull", "hairy", "diversity", "ut", "reverse", "deposit", "seminar", "investments", "latina", "wheels",
        "specify", "accessibility", "dutch", "sensitive", "templates", "formats", "tab", "depends", "boots", "holds",
        "router", "concrete", "si", "editing", "folder", "completion", "upload", "pulse", "universities", "technique",
        "contractors", "voting", "courts", "notices", "subscriptions", "calculate", "alexander", "broadcast", "converted", "metro",
        "anniversary", "improvements", "strip", "specification", "pearl", "accident", "nick", "accessible", "accessory", "resident",
        "plot", "possibly", "airline", "typically", "representation", "regard", "pump", "exists", "arrangements", "smooth",
        "conferences", "strike", "consumption", "flashing", "narrow", "afternoon", "threat", "surveys", "sitting", "putting",
        "consultant", "controller", "ownership", "committees", "penis", "legislative", "researchers", "trailer", "castle", "gardens",
        "missed", "unsubscribe", "antique", "labels", "willing", "bio", "molecular", "upskirt", "acting", "heads",
        "stored", "exam", "logos", "residence", "attorneys", "milfs", "antiques", "density", "hundred", "operators",
        "strange", "sustainable", "philippines", "statistical", "beds", "breasts", "mention", "innovation", "employers", "grey",
        "parallel", "honda", "amended", "operate", "bills", "bold", "bathroom", "stable", "opera", "definitions",
        "doctors", "lesson", "cinema", "asset", "ag", "scan", "elections", "drinking", "blowjobs", "reaction",
        "blank", "enhanced", "entitled", "severe", "generate", "stainless", "newspapers", "hospitals", "deluxe", "humor",
        "aged", "monitors", "exception", "lived", "duration", "bulk", "successfully", "pursuant", "fabric", "visits",
        "primarily", "tight", "domains", "capabilities", "contrast", "recommendation", "flying", "recruitment", "sin", "berlin",
        "cute", "organized", "ba", "para", "siemens", "adoption", "improving", "expensive", "meant", "capture",
        "pounds", "buffalo", "organisations", "plane", "explained", "seed", "programmes", "desire", "expertise", "mechanism",
        "camping", "ee", "jewellery", "meets", "welfare", "peer", "caught", "eventually", "marked", "driven",
        "measured", "bottle", "agreements", "considering", "innovative", "marshall", "massage", "rubber", "conclusion", "closing",
        "thousand", "meat", "legend", "grace", "ing", "python", "monster", "bang", "villa", "bone",
        "columns", "disorders", "bugs", "collaboration", "detection", "cookies", "inner", "formation", "tutorial", "med",
        "engineers", "entity", "cruises", "gate", "holder", "proposals", "moderator", "tutorials", "settlement", "roman",
        "duties", "valuable", "erotic", "tone", "collectables", "ethics", "forever", "dragon", "busy", "captain",
        "fantastic", "imagine", "brings", "heating", "leg", "neck", "wing", "governments", "purchasing", "scripts",
        "stereo", "appointed", "taste", "dealing", "commit", "tiny", "operational", "rail", "airlines", "liberal",
        "jay", "trips", "gap", "sides", "tube", "turns", "corresponding", "descriptions", "cache", "belt",
        "jacket", "determination", "animation", "oracle", "er", "lease", "productions", "aviation", "hobbies", "proud",
        "excess", "disaster", "console", "commands", "instructor", "giant", "achieved", "injuries", "shipped", "bestiality",
        "seats", "approaches", "biz", "alarm", "voltage", "usual", "loading", "stamps", "appeared", "franklin",
        "angle", "rob", "vinyl", "highlights", "mining", "designers", "ongoing", "worst", "imaging", "betting",
        "scientists", "liberty", "blackjack", "era", "convert", "possibility", "analyst", "commissioner", "dangerous", "garage",
        "exciting", "reliability", "thongs", "unfortunately", "respectively", "volunteers", "attachment", "ringtone", "morgan", "derived",
        "pleasure", "honor", "asp", "oriented", "eagle", "desktops", "pants", "nurse", "prayer", "appointment",
        "workshops", "hurricane", "quiet", "luck", "postage", "producer", "represented", "mortgages", "dial", "cheese",
        "comic", "carefully", "jet", "productivity", "investors", "crown", "par", "underground", "diagnosis", "maker",
        "crack", "principle", "picks", "vacations", "gang", "semester", "calculated", "fetish", "applies", "casinos",
        "appearance", "smoke", "apache", "filters", "incorporated", "craft", "cake", "notebooks", "apart", "fellow",
        "blind", "lounge", "mad", "algorithm", "semi", "coins", "gross", "strongly", "cafe", "valentine",
        "ken", "proteins", "horror", "familiar", "capable", "till", "involving", "pen", "investing", "admission",
        "shoe", "elected", "carrying", "victory", "sand", "madison", "terrorism", "joy", "editions", "mainly",
        "ethnic", "ran", "parliament", "actor", "finds", "seal", "situations", "fifth", "allocated", "citizen",
        "vertical", "corrections", "structural", "municipal", "describes", "prize", "occurs", "absolute", "disabilities", "consists",
        "anytime", "substance", "prohibited", "addressed", "lies", "pipe", "soldiers", "guardian", "lecture", "simulation",
        "layout", "initiatives", "ill", "concentration", "classics", "lay", "interpretation", "horses", "dirty", "deck",
        "donate", "taught", "bankruptcy", "worker", "optimization", "alive", "temple", "substances", "prove", "discovered",
        "wings", "breaks", "genetic", "restrictions", "participating", "waters", "promise", "thin", "exhibition", "prefer",
        "ridge", "cabinet", "modem", "bringing", "sick", "dose", "evaluate", "tiffany", "tropical", "collect",
        "bet", "composition", "streets", "nationwide", "vector", "definitely", "shaved", "turning", "buffer", "purple",
        "existence", "commentary", "limousines", "developments", "def", "immigration", "destinations", "lets", "mutual", "pipeline",
        "necessarily", "syntax", "li", "attribute", "prison", "skill", "chairs", "everyday", "apparently", "surrounding",
        "mountains", "moves", "popularity", "inquiry", "checked", "exhibit", "throw", "trend", "sierra", "visible",
        "cats", "desert", "ya", "oldest", "busty", "coordinator", "obviously", "mercury", "steven", "handbook",
        "navigate", "worse", "summit", "victims", "spaces", "fundamental", "burning", "escape", "coupons", "somewhat",
        "receiver", "substantial", "progressive", "boats", "glance", "championship", "arcade", "impossible", "tells", "obvious",
        "fiber", "depression", "graph", "covering", "platinum", "judgment", "bedrooms", "talks", "filing", "foster",
        "modeling", "passing", "awarded", "testimonials", "trials", "tissue", "memorabilia", "masters", "bonds", "cartridge",
        "explanation", "folk", "org", "commons", "subsection", "fraud", "electricity", "permitted", "spectrum", "arrival",
        "okay", "pottery", "emphasis", "roger", "aspect", "workplace", "awesome", "confirmed", "counts", "priced",
        "wallpapers", "hist", "crash", "lift", "desired", "inter", "closer", "assumes", "heights", "shadow",
        "riding", "infection", "expense", "grove", "eligibility", "venture", "clinic", "healing", "princess", "mall",
        "entering", "packet", "spray", "studios", "involvement", "dad", "buttons", "placement", "observations", "funded",
        "winners", "extend", "roads", "subsequent", "pat", "rolling", "fell", "motorcycle", "yard", "disclosure",
        "establishment", "memories", "nelson", "te", "arrived", "creates", "faces", "tourist", "cocks", "mayor",
        "murder", "sean", "adequate", "senator", "yield", "presentations", "grades", "cartoons", "pour", "digest",
        "reg", "lodging", "dust", "hence", "wiki", "entirely", "replaced", "radar", "rescue", "undergraduate",
        "losses", "combat", "reducing", "stopped", "occupation", "lakes", "butt", "donations", "associations", "closely",
        "radiation", "diary", "seriously", "kings", "shooting", "kent", "adds", "ear", "flags", "baker",
        "launched", "elsewhere", "pollution", "conservative", "guestbook", "shock", "effectiveness", "walls", "abroad", "ebony",
        "tie", "ward", "drawn", "visited", "roof", "walker", "demonstrate", "atmosphere", "suggests", "kiss",
        "beast", "operated", "experiment", "targets", "overseas", "purchases", "dodge", "counsel", "federation", "pizza",
        "invited", "yards", "assignment", "chemicals", "mod", "farmers", "queries", "rush", "absence", "nearest",
        "cluster", "vendors", "whereas", "yoga", "serves", "woods", "surprise", "lamp", "partial", "shoppers",
        "everybody", "couples", "ranking", "jokes", "sublime", "counseling", "palace", "acceptable", "satisfied", "glad",
        "wins", "measurements", "verify", "globe", "trusted", "copper", "rack", "medication", "warehouse", "shareware",
        "rep", "kerry", "receipt", "supposed", "ordinary", "nobody", "ghost", "violation", "configure", "stability",
        "applying", "southwest", "boss", "pride", "institutional", "expectations", "independence", "knowing", "reporter", "metabolism",
        "champion", "cloudy", "personally", "chile", "anna", "plenty", "solo", "sentence", "throat", "ignore",
        "maria", "uniform", "excellence", "wealth", "tall", "somewhere", "vacuum", "dancing", "attributes", "recognize",
        "brass", "writes", "plaza", "outcomes", "survival", "quest", "publish", "sri", "screening", "toe",
        "thumbnail", "trans", "whenever", "nova", "lifetime", "pioneer", "booty", "forgotten", "acrobat", "plates",
        "acres", "venue", "athletic", "thermal", "essays", "behaviour", "vital", "telling", "fairly", "coastal",
        "charity", "intelligent", "excel", "modes", "obligation", "wake", "stupid", "harbor", "traveler", "segment",
        "realize", "regardless", "enemy", "puzzle", "rising", "aluminum", "wells", "opens", "insight", "shit",
        "restricted", "republican", "secrets", "lucky", "latter", "merchants", "thick", "trailers", "repeat", "syndrome",
        "attendance", "penalty", "drum", "glasses", "enables", "builder", "vista", "chips", "terry", "flood",
        "ease", "arguments", "orgy", "arena", "adventures", "pupils", "announcement", "tabs", "outcome", "appreciate",
        "expanded", "casual", "grown", "polish", "lovely", "extras", "centres", "jerry", "clause", "smile",
        "lands", "troops", "indoor", "armed", "broker", "charger", "regularly", "believed", "pine", "cooling",
        "tend", "gulf", "rick", "trucks", "mechanisms", "divorce", "laura", "shopper", "partly", "customize",
        "tradition", "candy", "pills", "tiger", "folks", "sensor", "exposed", "telecom", "hunt", "angels",
        "deputy", "indicators", "sealed", "emissions", "physicians", "loaded", "complaint", "scenes", "experiments", "balls",
        "boost", "spanking", "scholarship", "governance", "mill", "founded", "supplements", "chronic", "icons", "tranny",
        "moral", "den", "catering", "finger", "keeps", "pound", "locate", "camcorder", "trained", "burn",
        "implementing", "roses", "labs", "ourselves", "bread", "tobacco", "wooden", "motors", "tough", "incident",
        "gonna", "dynamics", "lie", "conversation", "decrease", "chest", "pension", "billy", "revenues", "emerging",
        "worship", "bukkake", "capability", "fe", "craig", "herself", "producing", "churches", "precision", "damages",
        "reserves", "contributed", "solve", "shorts", "reproduction", "minority", "diverse", "amp", "ingredients", "ah",
        "johnny", "sole", "franchise", "recorder", "complaints", "facing", "nancy", "promotions", "tones", "passion",
        "rehabilitation", "maintaining", "sight", "laid", "clay", "defence", "patches", "weak", "refund", "towns",
        "environments", "divided", "reception", "wise", "emails", "cyprus", "odds", "correctly", "insider", "seminars",
        "consequences", "makers", "hearts", "geography", "appearing", "integrity", "worry", "discrimination", "eve", "carter",
        "legacy", "marc", "pleased", "danger", "vitamin", "widely", "processed", "phrase", "genuine", "raising",
        "implications", "functionality", "paradise", "hybrid", "reads", "roles", "intermediate", "emotional", "sons", "leaf",
        "pad", "glory", "platforms", "ja", "bigger", "billing", "diesel", "versus", "combine", "overnight",
        "geographic", "exceed", "rod", "fault", "preliminary", "districts", "introduce", "silk", "promotional", "babies",
        "bi", "compiled", "romantic", "revealed", "specialists", "generator", "albert", "examine", "jimmy", "graham",
        "suspension", "bristol", "sad", "correction", "wolf", "slowly", "authentication", "communicate", "rugby", "supplement",
        "showtimes", "cal", "portions", "infant", "promoting", "sectors", "fluid", "grounds", "fits", "kick",
        "regards", "meal", "ta", "hurt", "machinery", "bandwidth", "unlike", "equation", "baskets", "probability",
        "pot", "dimension", "wright", "barry", "proven", "schedules", "admissions", "cached", "warren", "slip",
        "studied", "reviewer", "involves", "quarterly", "profits", "devil", "grass", "comply", "florist", "illustrated",
        "cherry", "continental", "alternate", "achievement", "limitations", "webcam", "cuts", "funeral", "earrings", "enjoyed",
        "automated", "chapters", "pee", "charlie", "quebec", "nipples", "passenger", "convenient", "mars", "sized",
        "manga", "noticed", "socket", "silent", "literary", "egg", "signals", "caps", "orientation", "pill",
        "theft", "childhood", "swing", "symbols", "lat", "meta", "humans", "analog", "facial", "choosing",
        "talent", "dated", "flexibility", "seeker", "wisdom", "shoot", "boundary", "mint", "offset", "payday",
        "elite", "gi", "spin", "holders", "believes", "poems", "deadline", "jurisdiction", "robot", "displaying",
        "witness", "collins", "equipped", "stages", "encouraged", "sur", "winds", "powder", "broadway", "acquired",
        "assess", "wash", "cartridges", "stones", "entrance", "gnome", "roots", "declaration", "losing", "attempts",
        "gadgets", "noble", "automation", "impacts", "rev", "gospel", "advantages", "shore", "loves", "induced",
        "knight", "preparing", "loose", "aims", "recipient", "linking", "extensions", "appeals", "earned", "illness",
        "athletics", "southeast", "ho", "alternatives", "pending", "parker", "determining", "personalized", "sh", "conditioning",
        "teenage", "soap", "ae", "triple", "cooper", "jam", "secured", "unusual", "answered", "partnerships",
        "destruction", "slots", "increasingly", "migration", "disorder", "routine", "toolbar", "basically", "rocks", "conventional",
        "titans", "applicants", "wearing", "axis", "sought", "genes", "mounted", "habitat", "firewall", "median",
        "guns", "scanner", "herein", "occupational", "animated", "horny", "judicial", "adjustment", "hero", "integer",
        "treatments", "bachelor", "attitude", "camcorders", "engaged", "falling", "basics", "carpet", "lenses", "binary",
        "genetics", "attended", "difficulty", "punk", "collective", "coalition", "pi", "dropped", "enrollment", "duke",
        "ai", "pace", "besides", "wage", "producers", "collector", "arc", "hosts", "interfaces", "advertisers",
        "moments", "atlas", "strings", "dawn", "representing", "observation", "feels", "torture", "carl", "deleted",
        "coat", "restoration", "convenience", "returning", "ralph", "opposition", "container", "defendant", "warner", "confirmation",
        "app", "embedded", "inkjet", "supervisor", "wizard", "corps", "actors", "liver", "peripherals", "liable",
        "brochure", "morris", "bestsellers", "petition", "recall", "antenna", "picked", "assumed", "departure", "belief",
        "killing", "bikini", "shoulder", "decor", "lookup", "texts", "brokers", "ion", "diameter", "doll",
        "podcast", "tit", "seasons", "interactions", "refine", "bidder", "singer", "herald", "literacy", "fails",
        "aging", "intervention", "pissing", "fed", "attraction", "diving", "invite", "modification", "latinas", "suppose",
        "customized", "reed", "involve", "moderate", "terror", "younger", "thirty", "mice", "opposite", "understood",
        "rapidly", "ban", "temp", "intro", "assurance", "fisting", "clerk", "happening", "vast", "mills",
        "outline", "amendments", "holland", "receives", "jeans", "metropolitan", "compilation", "verification", "fonts", "odd",
        "wrap", "refers", "mood", "favor", "veterans", "quiz", "sigma", "attractive", "occasion", "recordings",
        "victim", "demands", "sleeping", "careful", "beam", "gardening", "obligations", "arrive", "orchestra", "sunset",
        "tracked", "moreover", "minimal", "polyphonic", "lottery", "tops", "framed", "aside", "outsourcing", "licence",
        "adjustable", "allocation", "essay", "discipline", "demonstrated", "dialogue", "identifying", "alphabetical", "camps", "declared",
        "dispatched", "handheld", "trace", "disposal", "shut", "florists", "packs", "installing", "switches", "voluntary",
        "thou", "consult", "greatly", "blogging", "mask", "cycling", "midnight", "commonly", "pe", "photographer",
        "inform", "coal", "cry", "messaging", "quantum", "murray", "intent", "zoo", "largely", "pleasant",
        "announce", "constructed", "additions", "requiring", "spoke", "aka", "arrow", "engagement", "sampling", "rough",
        "weird", "tee", "refinance", "lion", "inspired", "holes", "weddings", "blade", "suddenly", "oxygen",
        "cookie", "meals", "canyon", "meters", "merely", "calendars", "arrangement", "conclusions", "passes", "bibliography",
        "pointer", "compatibility", "stretch", "furthermore", "permits", "cooperative", "sleeve", "cleaner", "cricket", "beef",
        "feeding", "stroke", "township", "rankings", "measuring", "cad", "hats", "robin", "strap", "headquarters",
        "sharon", "crowd", "transfers", "surf", "transformation", "remained", "attachments", "entities", "customs", "administrators",
        "personality", "rainbow", "hook", "roulette", "decline", "gloves", "medicare", "cord", "skiing", "cloud",
        "facilitate", "subscriber", "valve", "explains", "proceed", "feelings", "knife", "priorities", "shelf", "bookstore",
        "timing", "liked", "parenting", "adopt", "denied", "incredible", "freeware", "fucked", "donation", "outer",
        "crop", "deaths", "rivers", "commonwealth", "pharmaceutical", "manhattan", "tales", "workforce", "nodes", "fy",
        "thumbs", "seeds", "cited", "lite", "hub", "targeted", "organizational", "realized", "twelve", "founder",
        "decade", "dispute", "tired", "adverse", "everywhere", "excerpt", "eng", "steam", "discharge", "ef",
        "drinks", "ace", "voices", "acute", "climbing", "stood", "sing", "tons", "perfume", "carol",
        "honest", "hazardous", "restore", "stack", "methodology", "somebody", "sue", "housewares", "reputation", "resistant",
        "democrats", "recycling", "hang", "curve", "creator", "amber", "qualifications", "museums", "coding", "tracker",
        "variation", "passage", "transferred", "trunk", "hiking", "damn", "headset", "photograph", "waves", "camel",
        "distributor", "lamps", "underlying", "hood", "wrestling", "suicide", "archived", "photoshop", "chi", "gathering",
        "projection", "juice", "chase", "mathematical", "logical", "sauce", "fame", "extract", "specialized", "diagnostic",
        "panama", "payable", "corporations", "courtesy", "criticism", "automobile", "confidential", "statutory", "accommodations", "northeast",
        "downloaded", "judges", "retired", "remarks", "detected", "decades", "paintings", "walked", "arising", "bracelet",
        "ins", "eggs", "juvenile", "injection", "populations", "protective", "afraid", "acoustic", "railway", "cassette",
        "initially", "indicator", "pointed", "causing", "mistake", "locked", "eliminate", "fusion", "mineral", "sunglasses",
        "ruby", "steering", "beads", "fortune", "preference", "canvas", "threshold", "parish", "claimed", "screens",
        "cemetery", "planner", "flows", "stadium", "exploration", "fewer", "sequences", "coupon", "nurses", "stem",
        "proxy", "gangbang", "astronomy", "opt", "drew", "contests", "flu", "translate", "announces", "costume",
        "tagged", "voted", "killer", "bikes", "gates", "adjusted", "rap", "tune", "bishop", "pulled",
        "corn", "shaped", "compression", "seasonal", "establishing", "farmer", "counters", "puts", "constitutional", "grew",
        "perfectly", "tin", "slave", "instantly", "cultures", "coaching", "examined", "trek", "encoding", "litigation",
        "submissions", "heroes", "painted", "broadcasting", "horizontal", "artwork", "cosmetic", "resulted", "portrait", "terrorist",
        "informational", "ethical", "carriers", "ecommerce", "mobility", "floral", "builders", "ties", "struggle", "schemes",
        "suffering", "neutral", "fisher", "rat", "spears", "prospective", "dildos", "bedding", "ultimately", "joining",
        "heading", "equally", "artificial", "bearing", "spectacular", "coordination", "connector", "brad", "combo", "seniors",
        "worlds", "guilty", "affiliated", "activation", "naturally", "haven", "tablet", "jury", "dos", "tail",
        "subscribers", "charm", "lawn", "violent", "underwear", "basin", "soup", "potentially", "ranch", "constraints",
        "crossing", "inclusive", "dimensional", "cottage", "drunk", "considerable", "crimes", "resolved", "byte", "toner",
        "nose", "latex", "branches", "anymore", "holdings", "alien", "locator", "selecting", "processors", "pantyhose",
        "broke", "difficulties", "complexity", "constantly", "browsing", "resolve", "presidential", "documentary", "cod", "territories",
        "thesis", "thru", "jews", "nylon", "discs", "rocky", "bargains", "frequent", "trim", "ceiling",
        "pixels", "ensuring", "legislature", "hospitality", "gen", "anybody", "procurement", "diamonds", "fleet", "untitled",
        "bunch", "totals", "singing", "theoretical", "afford", "exercises", "starring", "referral", "surveillance", "optimal",
        "quit", "distinct", "protocols", "lung", "highlight", "substitute", "inclusion", "hopefully", "brilliant", "turner",
        "sucking", "cents", "ti", "gel", "spoken", "omega", "evaluated", "stayed", "civic", "assignments",
        "manuals", "sees", "termination", "watched", "saver", "thereof", "grill", "households", "redeem", "rogers",
        "grain", "authentic", "regime", "wanna", "wishes", "bull", "architectural", "depend", "differ", "macintosh",
        "movements", "ranging", "repairs", "breath", "amenities", "virtually", "cole", "mart", "candle", "hanging",
        "colored", "authorization", "tale", "verified", "formerly", "projector", "situated", "comparative", "seeks", "herbal",
        "loving", "strictly", "routing", "docs", "psychological", "surprised", "retailer", "vitamins", "elegant", "gains",
        "renewal", "vid", "genealogy", "opposed", "deemed", "scoring", "expenditure", "panties", "sisters", "critics",
        "connectivity", "spots", "oo", "algorithms", "hacker", "similarly", "margin", "coin", "solely", "fake",
        "salon", "collaborative", "norman", "excluding", "turbo", "headed", "voters", "cure", "madonna", "commander",
        "arch", "murphy", "thinks", "suggestion", "soldier", "aimed", "bomb", "harm", "interval", "mirrors",
        "spotlight", "tricks", "reset", "brush", "investigate", "thy", "panels", "repeated", "assault", "connecting",
        "spare", "logistics", "deer", "tongue", "bowling", "danish", "pal", "monkey", "proportion", "filename",
        "skirt", "florence", "invest", "honey", "um", "analyses", "drawings", "significance", "scenario", "ye",
        "lovers", "atomic", "symposium", "arabic", "gauge", "essentials", "junction", "protecting", "faced", "mat",
        "solving", "transmitted", "weekends", "screenshots", "produces", "oven", "ted", "intensive", "chains", "sixth",
        "engage", "deviant", "noon", "switching", "quoted", "adapters", "correspondence", "farms", "imports", "supervision",
        "cheat", "bronze", "expenditures", "sandy", "separation", "testimony", "suspect", "celebrities", "macro", "sender",
        "mandatory", "boundaries", "crucial", "syndication", "gym", "celebration", "adjacent", "filtering", "tuition", "spouse",
        "exotic", "viewer", "threats", "puzzles", "reaching", "damaged", "cams", "receptor", "piss", "laugh",
        "surgical", "destroy", "citation", "pitch", "autos", "yo", "premises", "perry", "proved", "offensive",
        "imperial", "dozen", "benjamin", "deployment", "teeth", "cloth", "studying", "colleagues", "stamp", "lotus",
        "salmon", "separated", "cargo", "tan", "directive", "mate", "starter", "upgrades", "likes", "butter",
        "pepper", "weapon", "luggage", "burden", "chef", "tapes", "zones", "races", "isle", "stylish",
        "slim", "maple", "luke", "grocery", "offshore", "governing", "retailers", "depot", "comp", "alt",
        "pie", "blend", "occasionally", "attending", "emission", "spec", "finest", "realty", "bow", "recruiting",
        "apparent", "instructional", "autumn", "traveling", "probe", "midi", "permissions", "biotechnology", "toilet", "ranked",
        "jackets", "routes", "packed", "excited", "outreach", "mounting", "recover", "tied", "balanced", "prescribed",
        "timely", "talked", "debug", "delayed", "chuck", "reproduced", "hon", "dale", "explicit", "calculation",
        "villas", "ebook", "consolidated", "boob", "exclude", "peeing", "occasions", "brooks", "equations", "newton",
        "oils", "sept", "exceptional", "anxiety", "bingo", "whilst", "spatial", "respondents", "unto", "ceramic",
        "prompt", "precious", "minds", "annually", "considerations", "scanners", "pays", "cox", "fingers", "sunny",
        "ebooks", "delivers", "necklace", "musicians", "composite", "unavailable", "cedar", "arranged", "lang", "theaters",
        "advocacy", "stud", "fold", "essentially", "designing", "threaded", "qualify", "fingering", "hopes", "assessments",
        "mason", "diagram", "burns", "pumps", "slut", "ejaculation", "footwear", "peoples", "victor", "pos",
        "attach", "licenses", "removing", "advised", "spider", "ranges", "pairs", "sensitivity", "trails", "preservation",
        "isolated", "interim", "assisted", "divine", "streaming", "approve", "chose", "compound", "intensity", "technological",
        "syndicate", "abortion", "dialog", "venues", "blast", "wellness", "calcium", "antivirus", "addressing", "pole",
        "discounted", "shield", "harvest", "membrane", "previews", "constitute", "locally", "concluded", "pickup", "desperate",
        "mothers", "demonstration", "governmental", "manufactured", "candles", "graduation", "mega", "bend", "sailing", "variations",
        "moms", "sacred", "addiction", "morocco", "chrome", "tommy", "refused", "brake", "exterior", "greeting",
        "ecology", "oliver", "congo", "glen", "nav", "delays", "synthesis", "olive", "undefined", "unemployment",
        "cyber", "scored", "enhancement", "clone", "dicks", "velocity", "lambda", "relay", "composed", "tears",
        "performances", "oasis", "baseline", "cab", "angry", "fa", "societies", "silicon", "identical", "petroleum",
        "compete", "lover", "belong", "lips", "escort", "retention", "exchanges", "pond", "rolls", "soundtrack",
        "wondering", "daddy", "ferry", "rabbit", "profession", "seating", "dam", "separately", "physiology", "collecting",
        "das", "exports", "tire", "participant", "scholarships", "recreational", "chad", "electron", "loads", "friendship",
        "heather", "passport", "motel", "unions", "treasury", "warrant", "frozen", "occupied", "josh", "royalty",
        "scales", "rally", "observer", "sunshine", "strain", "drag", "ceremony", "somehow", "arrested", "expanding",
        "provincial", "investigations", "ripe", "rely", "medications", "gained", "dying", "laundry", "stuck", "placing",
        "stops", "homework", "adjust", "assessed", "advertiser", "enabling", "encryption", "filling", "downloadable", "sophisticated",
        "imposed", "silence", "focuses", "soviet", "possession", "laboratories", "treaty", "vocal", "trainer", "organ",
        "stronger", "volumes", "advances", "vegetables", "lemon", "toxic", "thumbnails", "darkness", "nuts", "nail",
        "vienna", "implied", "span", "sox", "stockings", "joke", "respondent", "packing", "statute", "rejected",
        "satisfy", "destroyed", "shelter", "chapel", "manufacture", "layers", "guided", "vulnerability", "accountability", "celebrate",
        "accredited", "appliance", "compressed", "mixture", "zoophilia", "bench", "tub", "rider", "scheduling", "radius",
        "perspectives", "mortality", "logging", "christians", "borders", "therapeutic", "pads", "butts", "inns", "bobby",
        "impressive", "sheep", "accordingly", "architect", "railroad", "lectures", "challenging", "wines", "nursery", "harder",
        "cups", "ash", "microwave", "cheapest", "accidents", "relocation", "contributors", "salad", "tender", "violations",
        "foam", "temperatures", "paste", "clouds", "competitions", "discretion", "preserve", "poem", "vibrator", "unsigned",
        "staying", "cosmetics", "easter", "theories", "repository", "praise", "jo", "concentrations", "vibrators", "veteran",
        "streams", "landing", "signing", "executed", "negotiations", "realistic", "showcase", "integral", "asks", "relax",
        "generating", "congressional", "synopsis", "hardly", "prairie", "reunion", "composer", "bean", "sword", "absent",
        "photographic", "sells", "hoping", "accessed", "spirits", "modifications", "coral", "pixel", "float", "colin",
        "bias", "imported", "paths", "bubble", "acquire", "contrary", "millennium", "tribune", "vessel", "acids",
        "focusing", "viruses", "cheaper", "admitted", "dairy", "admit", "mem", "fancy", "equality", "achieving",
        "tap", "stickers", "fisheries", "exceptions", "reactions", "leasing", "beliefs", "companion", "squad", "analyze",
        "scroll", "relate", "divisions", "swim", "wages", "additionally", "suffer", "forests", "fellowship", "nano",
        "invalid", "concerts", "martial", "males", "retain", "colours", "execute", "tunnel", "genres", "patents",
        "copyrights", "chaos", "wheat", "chronicles", "obtaining", "beaver", "updating", "distribute", "readings", "decorative",
        "confused", "compiler", "enlargement", "eagles", "bases", "accused", "bee", "campaigns", "unity", "loud",
        "conjunction", "bride", "rats", "defines", "airports", "instances", "indigenous", "begun", "brunette", "packets",
        "anchor", "socks", "validation", "parade", "corruption", "stat", "trigger", "incentives", "cholesterol", "gathered",
        "notified", "differential", "beaches", "folders", "dramatic", "surfaces", "terrible", "routers", "pendant", "dresses",
        "baptist", "scientist", "hiring", "clocks", "arthritis", "bios", "females", "nevertheless", "reflects", "taxation",
        "fever", "cuisine", "surely", "practitioners", "transcript", "myspace", "theorem", "inflation", "thee", "ruth",
        "pray", "stylus", "compounds", "pope", "drums", "contracting", "topless", "structured", "reasonably", "jeep",
        "chicks", "bare", "hung", "cattle", "radical", "graduates", "rover", "recommends", "controlling", "treasure",
        "reload", "distributors", "flame", "tanks", "assuming", "monetary", "elderly", "pit", "mono", "particles",
        "floating", "extraordinary", "tile", "indicating", "bolivia", "spell", "hottest", "stevens", "coordinate", "exclusively",
        "alleged", "limitation", "widescreen", "compile", "squirting", "webster", "struck", "illustration", "warnings", "construct",
        "apps", "inquiries", "bridal", "annex", "mag", "inspiration", "tribal", "curious", "affecting", "freight",
        "rebate", "eclipse", "downloading", "rec", "shuttle", "aggregate", "stunning", "cycles", "affects", "forecasts",
        "detect", "sluts", "actively", "ciao", "knee", "prep", "complicated", "chem", "fastest", "butler",
        "injured", "decorating", "payroll", "cookbook", "expressions", "ton", "courier", "uploaded", "hints", "collapse",
        "connectors", "twinks", "unlikely", "oe", "gif", "pros", "conflicts", "techno", "beverage", "tribute",
        "wired", "immune", "travelers", "forestry", "barriers", "cant", "rarely", "infected", "offerings", "genesis",
        "barrier", "argue", "incorrect", "trains", "metals", "bicycle", "furnishings", "letting", "arise", "thereby",
        "particle", "perception", "minerals", "advise", "humidity", "bottles", "boxing", "bangkok", "renaissance", "pathology",
        "bra", "ordinance", "photographers", "bitch", "infections", "chess", "operates", "configured", "survive", "oscar",
        "festivals", "menus", "possibilities", "duck", "reveal", "canal", "amino", "phi", "contributing", "herbs",
        "clinics", "cow", "analytical", "missions", "lying", "costumes", "strict", "dive", "circulation", "drill",
        "offense", "threesome", "protest", "handjob", "assumption", "hobby", "tries", "invention", "nickname", "technician",
        "executives", "enquiries", "washing", "staffing", "cognitive", "exploring", "trick", "enquiry", "closure", "raid",
        "timber", "volt", "intense", "div", "playlist", "registrar", "showers", "supporters", "ruling", "steady",
        "dirt", "statutes", "withdrawal", "drops", "predicted", "wider", "cancellation", "enrolled", "sensors", "screw",
        "ministers", "publicly", "hourly", "blame", "geneva", "veterinary", "acer", "reseller", "handed", "suffered",
        "intake", "informal", "relevance", "incentive", "butterfly", "mechanics", "heavily", "swingers", "fifty", "headers",
        "mistakes", "numerical", "ons", "geek", "uncle", "defining", "counting", "reflection", "sink", "accompanied",
        "assure", "invitation", "devoted", "sodium", "randy", "spirituality", "hormone", "meanwhile", "proprietary", "timothy",
        "brick", "grip", "naval", "medieval", "porcelain", "bridges", "captured", "watt", "decent", "casting",
        "translated", "shortly", "columnists", "pins", "reno", "donna", "warrior", "diploma", "cabin", "innocent",
        "scanning", "ide", "consensus", "polo", "valium", "copying", "delivering", "cordless", "horn", "fired",
        "journalism", "trivia", "frog", "grammar", "intention", "disagree", "tires", "logs", "undertaken", "hazard",
        "retro", "statewide", "semiconductor", "episodes", "circular", "anger", "mainland", "illustrations", "suits", "chances",
        "interact", "snap", "happiness", "substantially", "bizarre", "ur", "olympics", "fruits", "identifier", "geo",
        "ribbon", "calculations", "doe", "conducting", "startup", "kissing", "handy", "swap", "exempt", "crops",
        "reduces", "accomplished", "calculators", "geometry", "impression", "abs", "flip", "guild", "correlation", "gorgeous",
        "capitol", "sim", "dishes", "nervous", "refuse", "extends", "fragrance", "replica", "plumbing", "brussels",
        "tribe", "neighbors", "trades", "superb", "buzz", "transparent", "nuke", "rid", "trinity", "charleston",
        "handled", "legends", "boom", "calm", "champions", "floors", "selections", "projectors", "inappropriate", "exhaust",
        "comparing", "shanghai", "speaks", "burton", "vocational", "copied", "scotia", "farming", "gibson", "pharmacies",
        "fork", "troy", "roller", "introducing", "batch", "organize", "appreciated", "alter", "latino", "edges",
        "mixing", "handles", "skilled", "fitted", "harmony", "distinguished", "asthma", "projected", "assumptions", "shareholders",
        "twins", "developmental", "rip", "regulated", "triangle", "amend", "anticipated", "oriental", "reward", "completing",
        "hydrogen", "sprint", "comparable", "chick", "advocate", "sims", "confusion", "copyrighted", "tray", "inputs",
        "warranties", "genome", "escorts", "documented", "thong", "medal", "paperbacks", "coaches", "vessels", "harbour",
        "walks", "sucks", "sol", "keyboards", "sage", "knives", "eco", "vulnerable", "arrange", "artistic",
        "bat", "honors", "booth", "indie", "reflected", "unified", "bones", "breed", "detector", "ignored",
        "polar", "fallen", "precise", "respiratory", "notifications", "transexual", "mainstream", "invoice", "evaluating", "lip",
        "subcommittee", "sap", "gather", "maternity", "backed", "colonial", "motels", "forming", "embassy", "cave",
        "journalists", "danny", "slight", "proceeds", "indirect", "amongst", "wool", "foundations", "arrest", "volleyball",
        "horizon", "nu", "deeply", "toolbox", "marina", "liabilities", "prizes", "browsers", "decreased", "patio",
        "tolerance", "surfing", "creativity", "describing", "optics", "pursue", "lightning", "overcome", "eyed", "ou",
        "quotations", "grab", "inspector", "attract", "beans", "bookmarks", "disable", "snake", "succeed", "lending",
        "oops", "reminder", "nipple", "xi", "searched", "behavioral", "riverside", "bathrooms", "plains", "insights",
        "abilities", "initiated", "za", "karaoke", "trap", "lonely", "fool", "nonprofit", "suspended", "hereby",
        "observe", "containers", "attitudes", "berry", "collar", "simultaneously", "racial", "integrate", "sociology", "mobiles",
        "screenshot", "exhibitions", "confident", "retrieved", "exhibits", "officially", "consortium", "dies", "terrace", "bacteria",
        "replied", "seafood", "novels", "recipients", "playboy", "ought", "delicious", "traditions", "jail", "safely",
        "finite", "kidney", "periodically", "fixes", "sends", "durable", "allied", "throws", "moisture", "roster",
        "referring", "spencer", "transform", "timer", "tablets", "tuning", "gotten", "educators", "tyler", "futures",
        "vegetable", "verse", "highs", "humanities", "independently", "wanting", "custody", "scratch", "launches", "alignment",
        "masturbating", "comm", "competitors", "rocket", "aye", "bullet", "towers", "racks", "lace", "nasty",
        "visibility", "latitude", "consciousness", "tumor", "ugly", "deposits", "mistress", "encounter", "trustees", "watts",
        "reprints", "hart", "resolutions", "ment", "accessing", "forty", "tubes", "attempted", "col", "midlands",
        "priest", "analysts", "queue", "trance", "locale", "yu", "bundle", "hammer", "invasion", "witnesses",
        "runner", "rows", "administered", "notion", "skins", "mailed", "spelling", "arctic", "exams", "rewards",
        "beneath", "strengthen", "defend", "medicaid", "infrared", "seventh", "gods", "welsh", "belly", "aggressive",
        "tex", "advertisements", "quarters", "stolen", "soonest", "disturbed", "determines", "sculpture", "poly", "ears",
        "dod", "fist", "naturals", "motivation", "lenders", "pharmacology", "fitting", "fixtures", "bloggers", "mere",
        "agrees", "passengers", "quantities", "consistently", "cons", "surplus", "elder", "sonic", "obituaries", "cheers",
        "dig", "taxi", "punishment", "appreciation", "subsequently", "om", "nat", "zoning", "gravity", "providence",
        "thumb", "restriction", "incorporate", "backgrounds", "treasurer", "guitars", "essence", "flooring", "lightweight", "mighty",
        "athletes", "humanity", "transcription", "holmes", "complications", "scholars", "scripting", "gis", "remembered", "galaxy",
        "snapshot", "caring", "worn", "synthetic", "shaw", "segments", "testament", "expo", "dominant", "twist",
        "specifics", "stomach", "partially", "buried", "newbie", "minimize", "ranks", "wilderness", "debut", "generations",
        "tournaments", "deny", "anatomy", "judy", "sponsorship", "headphones", "fraction", "trio", "proceeding", "cube",
        "defects", "uncertainty", "breakdown", "marker", "reconstruction", "subsidiary", "strengths", "clarity", "rugs", "encouraging",
        "furnished", "settled", "folding", "emirates", "terrorists", "airfare", "comparisons", "beneficial", "distributions", "vaccine",
        "crap", "fate", "promised", "penny", "robust", "bookings", "threatened", "republicans", "discusses", "porter",
        "jungle", "responded", "rim", "abstracts", "ivory", "alpine", "dis", "prediction", "pharmaceuticals", "fabulous",
        "remix", "alias", "thesaurus", "individually", "battlefield", "literally", "newer", "kay", "ecological", "spice",
        "oval", "implies", "soma", "ser", "cooler", "appraisal", "consisting", "maritime", "periodic", "submitting",
        "overhead", "prospect", "shipment", "breeding", "citations", "geographical", "donor", "tension", "trash", "shapes",
        "tier", "earl", "manor", "envelope", "diane", "homeland", "disclaimers", "championships", "excluded", "breeds",
        "rapids", "disco", "bailey", "finishing", "emotions", "wellington", "incoming", "prospects", "cleaners", "eternal",
        "cashiers", "cite", "aboriginal", "remarkable", "rotation", "nam", "preventing", "productive", "boulevard", "pig",
        "metric", "compliant", "minus", "penalties", "imagination", "refurbished", "varied", "grande", "closest", "activated",
        "actress", "mess", "conferencing", "assign", "politicians", "lit", "accommodate", "tigers", "aurora", "slides",
        "premiere", "lender", "villages", "shade", "chorus", "rhythm", "digit", "argued", "dietary", "symphony",
        "sudden", "accepting", "precipitation", "lions", "pools", "lyric", "isolation", "speeds", "sustained", "matched",
        "approximate", "rope", "rational", "programmer", "fighters", "chambers", "dump", "greetings", "inherited", "warming",
        "incomplete", "vocals", "chronicle", "fountain", "chubby", "grave", "legitimate", "biographies", "burner", "foo",
        "investigator", "plaintiff", "gentle", "prisoners", "deeper", "hose", "mediterranean", "nightlife", "footage", "worthy",
        "reveals", "architects", "saints", "entrepreneur", "carries", "sig", "freelance", "duo", "excessive", "devon",
        "screensaver", "saves", "regarded", "valuation", "unexpected", "cigarette", "fog", "characteristic", "lobby", "egyptian",
        "outlined", "consequently", "headline", "treating", "punch", "appointments", "gotta", "cowboy", "narrative", "enormous",
        "karma", "consist", "betty", "queens", "academics", "pubs", "quantitative", "shemales", "screensavers", "subdivision",
        "tribes", "defeat", "clicks", "distinction", "naughty", "hazards", "insured", "harper", "livestock", "exemption",
        "tenant", "sustainability", "cabinets", "tattoo", "shake", "algebra", "shadows", "holly", "formatting", "silly",
        "nutritional", "yea", "mercy", "freely", "sunrise", "wrapping", "mild", "fur", "weblogs", "timeline",
        "tar", "belongs", "readily", "affiliation", "soc", "fence", "nudist", "infinite", "ensures", "relatives",
        "clan", "legally", "shame", "satisfactory", "revolutionary", "bracelets", "sync", "civilian", "telephony", "mesa",
        "fatal", "remedy", "realtors", "breathing", "briefly", "thickness", "adjustments", "graphical", "genius", "discussing",
        "aerospace", "fighter", "meaningful", "flesh", "retreat", "adapted", "barely", "wherever", "estates", "rug",
        "democrat", "borough", "maintains", "failing", "shortcuts", "ka", "retained", "marble", "extending", "jesse",
        "specifies", "hull", "surrey", "briefing", "accreditation", "blackberry", "highland", "meditation", "modular", "microphone",
        "combining", "instrumental", "giants", "organizing", "shed", "balloon", "moderators", "memo", "ham", "solved",
        "tide", "standings", "partition", "invisible", "consoles", "funk", "magnet", "translations", "cayman", "jaguar",
        "reel", "sheer", "commodity", "posing", "wang", "kilometers", "bind", "thanksgiving", "rand", "urgent",
        "guarantees", "infants", "gothic", "cylinder", "witch", "buck", "indication", "eh", "congratulations", "cohen",
        "puppy", "acre", "graphs", "surround", "cigarettes", "revenge", "expires", "enemies", "lows", "controllers",
        "aqua", "emma", "consultancy", "finances", "accepts", "enjoying", "conventions", "patrol", "smell", "pest",
        "coordinates", "carnival", "roughly", "sticker", "promises", "responding", "reef", "physically", "divide", "stakeholders",
        "hydrocodone", "consecutive", "satin", "bon", "deserve", "attempting", "promo", "representations", "worried", "tunes",
        "garbage", "competing", "combines", "mas", "beth", "phrases", "kai", "peninsula", "boring", "dom",
        "jill", "accurately", "speeches", "reaches", "schema", "considers", "sofa", "catalogs", "ministries", "vacancies",
        "quizzes", "parliamentary", "prefix", "savannah", "barrel", "typing", "nerve", "dans", "planets", "deficit",
        "boulder", "pointing", "renew", "coupled", "metadata", "circuits", "floppy", "texture", "handbags", "jar",
        "somerset", "incurred", "acknowledge", "thoroughly", "thunder", "tent", "caution", "identifies", "questionnaire", "qualification",
        "locks", "modelling", "namely", "miniature", "hack", "dare", "euros", "interstate", "pirates", "aerial",
        "hawk", "consequence", "rebel", "systematic", "perceived", "origins", "hired", "makeup", "textile", "lamb",
        "presenting", "cos", "troubleshooting", "indexes", "pac", "centuries", "magnitude", "fragrances", "vocabulary", "licking",
        "earthquake", "fundraising", "markers", "weights", "geological", "assessing", "lasting", "wicked", "eds", "introduces",
        "kills", "roommate", "webcams", "pushed", "webmasters", "computational", "participated", "junk", "handhelds", "wax",
        "answering", "impressed", "slope", "reggae", "failures", "poet", "conspiracy", "surname", "theology", "nails",
        "evident", "whats", "rides", "rehab", "epic", "organizer", "nut", "allergy", "sake", "twisted",
        "combinations", "preceding", "merit", "enzyme", "cumulative", "planes", "tackle", "disks", "condo", "amplifier",
        "arbitrary", "prominent", "retrieve", "sans", "titanium", "fairy", "builds", "contacted", "shaft", "lean",
        "bye", "recorders", "occasional", "ana", "postings", "innovations", "kitty", "postcards", "dude", "drain",
        "monte", "fires", "blessed", "reviewing", "favors", "potato", "panic", "explicitly", "sticks", "leone",
        "transsexual", "citizenship", "excuse", "reforms", "basement", "onion", "strand", "sandwich", "lawsuit", "alto",
        "informative", "girlfriend", "cheque", "hierarchy", "influenced", "banners", "reject", "eau", "abandoned", "circles",
        "italic", "beats", "merry", "mil", "scuba", "gore", "complement", "cult", "dash", "passive",
        "valued", "cage", "checklist", "requesting", "courage", "scenarios", "gazette", "extraction", "batman", "elevation",
        "hearings", "lap", "utilization", "beverages", "calibration", "jake", "efficiently", "ping", "textbook", "dried",
        "entertaining", "prerequisite", "frontier", "settle", "stopping", "refugees", "knights", "hypothesis", "palmer", "medicines",
        "flux", "derby", "peaceful", "altered", "regression", "doctrine", "scenic", "trainers", "enhancements", "renewable",
        "intersection", "passwords", "sewing", "consistency", "collectors", "conclude", "recognised", "celebs", "propose", "lighter",
        "rage", "uh", "astrology", "advisors", "pavilion", "tactics", "trusts", "occurring", "supplemental", "travelling",
        "talented", "pillow", "induction", "precisely", "shorter", "spreading", "provinces", "relying", "finals", "steal",
        "parcel", "refined", "bo", "fifteen", "widespread", "incidence", "fears", "predict", "boutique", "acrylic",
        "rolled", "tuner", "incidents", "rays", "toddler", "enhancing", "flavor", "alike", "homeless", "horrible",
        "hungry", "metallic", "acne", "blocked", "interference", "warriors", "libs", "undo", "atmospheric", "halo",
        "parental", "referenced", "strikes", "lesser", "publicity", "marathon", "ant", "proposition", "gays", "pressing",
        "gasoline", "apt", "dressed", "scout", "exec", "dealt", "niagara", "warcraft", "charms", "catalyst",
        "trader", "bucks", "allowance", "denial", "designation", "thrown", "prepaid", "raises", "gem", "duplicate",
        "electro", "criterion", "badge", "wrist", "civilization", "analyzed", "heath", "tremendous", "ballot", "varying",
        "remedies", "validity", "trustee", "handjobs", "weighted", "angola", "squirt", "performs", "plastics", "realm",
        "corrected", "jenny", "helmet", "salaries", "postcard", "elephant", "encountered", "tsunami", "scholar", "nickel",
        "internationally", "surrounded", "psi", "buses", "geology", "creatures", "coating", "commented", "wallet", "cleared",
        "smilies", "vids", "accomplish", "boating", "drainage", "corners", "broader", "vegetarian", "rouge", "yeast",
        "yale", "pas", "clearing", "investigated", "ambassador", "coated", "intend", "contacting", "vegetation", "doom",
        "specially", "routines", "hitting", "beings", "bite", "aquatic", "reliance", "habits", "striking", "myth",
        "infectious", "podcasts", "gig", "gilbert", "continuity", "brook", "outputs", "phenomenon", "ensemble", "insulin",
        "assured", "biblical", "weed", "conscious", "accent", "eleven", "wives", "ambient", "utilize", "mileage",
        "prostate", "adaptor", "auburn", "unlock", "pledge", "vampire", "relates", "nitrogen", "xerox", "dice",
        "merger", "softball", "referrals", "quad", "dock", "differently", "mods", "framing", "organised", "musician",
        "blocking", "sorts", "integrating", "limiting", "dispatch", "revisions", "restored", "hint", "armor", "riders",
        "chargers", "remark", "dozens", "varies", "reasoning", "rendered", "picking", "charitable", "guards", "annotated",
        "convinced", "openings", "buys", "replacing", "researcher", "watershed", "councils", "occupations", "acknowledged", "nudity",
        "pockets", "granny", "pork", "equilibrium", "viral", "inquire", "pipes", "characterized", "laden", "cottages",
        "realtor", "merge", "privilege", "develops", "qualifying", "chassis", "estimation", "barn", "pushing", "fleece",
        "pediatric", "fare", "pierce", "dressing", "sperm", "bald", "craps", "fuji", "frost", "institutes",
        "mold", "dame", "sally", "yacht", "prefers", "drilling", "brochures", "herb", "ate", "breach",
        "whale", "traveller", "appropriations", "suspected", "tomatoes", "benchmark", "beginners", "instructors", "highlighted", "stationery",
        "idle", "mustang", "unauthorized", "clusters", "antibody", "competent", "momentum", "fin", "wiring", "io",
        "pastor", "mud", "uni", "shark", "contributor", "demonstrates", "phases", "grateful", "emerald", "gradually",
        "laughing", "grows", "cliff", "desirable", "tract", "ballet", "journalist", "bumper", "afterwards", "webpage",
        "religions", "garlic", "hostels", "shine", "explosion", "banned", "briefs", "signatures", "diffs", "cove",
        "ozone", "disciplines", "casa", "mu", "daughters", "conversations", "radios", "tariff", "opponent", "pasta",
        "simplified", "muscles", "serum", "wrapped", "swift", "motherboard", "inbox", "focal", "bibliographic", "vagina",
        "distant", "champagne", "ala", "decimal", "deviation", "superintendent", "dip", "samba", "hostel", "housewives",
        "employ", "penguin", "magical", "influences", "inspections", "irrigation", "miracle", "manually", "reprint", "hydraulic",
        "centered", "flex", "yearly", "penetration", "wound", "belle", "conviction", "hash", "omissions", "writings",
        "hamburg", "lazy", "retrieval", "qualities", "fathers", "carb", "charging", "marvel", "lined", "dow",
        "prototype", "importantly", "petite", "apparatus", "terrain", "dui", "pens", "explaining", "yen", "strips",
        "gossip", "rangers", "nomination", "empirical", "rotary", "worm", "dependence", "discrete", "beginner", "boxed",
        "lid", "sexuality", "polyester", "cubic", "deaf", "commitments", "suggesting", "sapphire", "kinase", "skirts",
        "mats", "remainder", "labeled", "privileges", "televisions", "specializing", "marking", "commodities", "sheriff", "griffin",
        "declined", "spies", "blah", "mime", "neighbor", "motorcycles", "elect", "highways", "concentrate", "intimate",
        "reproductive", "deadly", "cunt", "bunny", "chevy", "molecules", "rounds", "longest", "refrigerator", "intervals",
        "sentences", "dentists", "exclusion", "workstation", "holocaust", "keen", "flyer", "peas", "dosage", "receivers",
        "customise", "disposition", "variance", "navigator", "investigators", "baking", "marijuana", "adaptive", "computed", "needle",
        "baths", "cathedral", "brakes", "nirvana", "ko", "owns", "til", "sticky", "destiny", "generous",
        "madness", "emacs", "climb", "blowing", "fascinating", "landscapes", "heated", "computation", "hay", "cardiovascular",
        "cardiac", "salvation", "dover", "predictions", "accompanying", "brutal", "learners", "selective", "arbitration", "configuring",
        "token", "editorials", "zinc", "sacrifice", "seekers", "guru", "removable", "convergence", "yields", "levy",
        "suited", "numeric", "anthropology", "skating", "kinda", "emperor", "grad", "malpractice", "bras", "belts",
        "blacks", "educated", "rebates", "reporters", "burke", "proudly", "pix", "necessity", "rendering", "mic",
        "inserted", "pulling", "kyle", "obesity", "curves", "suburban", "touring", "vertex", "hepatitis", "nationally",
        "tomato", "waterproof", "expired", "travels", "flush", "waiver", "pale", "specialties", "humanitarian", "invitations",
        "functioning", "delight", "survivor", "cingular", "economies", "bacterial", "moses", "counted", "undertake", "declare",
        "continuously", "johns", "valves", "gaps", "impaired", "achievements", "donors", "tear", "jewel", "teddy",
        "convertible", "teaches", "ventures", "nil", "stranger", "tragedy", "nest", "pam", "dryer", "painful",
        "velvet", "tribunal", "ruled", "pensions", "prayers", "funky", "secretariat", "nowhere", "cop", "paragraphs",
        "gale", "joins", "adolescent", "nominations", "dim", "lately", "cancelled", "scary", "mattress", "likewise",
        "banana", "introductory", "cakes", "reservoir", "occurrence", "idol", "bloody", "mixer", "remind", "worcester",
        "demographic", "charming", "tooth", "disciplinary", "annoying", "respected", "stays", "disclose", "affair", "drove",
        "washer", "upset", "restrict", "springer", "beside", "mines", "portraits", "rebound", "logan", "mentor",
        "interpreted", "evaluations", "fought", "elimination", "metres", "hypothetical", "immigrants", "complimentary", "helicopter", "pencil",
        "freeze", "performer", "titled", "commissions", "sphere", "moss", "ratios", "concord", "graduated", "endorsed",
        "surprising", "walnut", "lance", "ladder", "unnecessary", "dramatically", "cork", "maximize", "senators", "workout",
        "mali", "bleeding", "colon", "likelihood", "lanes", "purse", "fundamentals", "contamination", "endangered", "compromise",
        "masturbation", "optimize", "stating", "dome", "leu", "expiration", "align", "peripheral", "bless", "engaging",
        "negotiation", "crest", "opponents", "triumph", "nominated", "confidentiality", "electoral", "welding", "orgasm", "deferred",
        "alternatively", "heel", "alloy", "condos", "plots", "polished", "yang", "gently", "locking", "controversial",
        "draws", "fridge", "blanket", "bloom", "lou", "recovered", "justify", "upgrading", "blades", "loops",
        "surge", "frontpage", "trauma", "aw", "advert", "possess", "demanding", "defensive", "sip", "flashers",
        "forbidden", "vanilla", "programmers", "monitored", "installations", "picnic", "souls", "arrivals", "spank", "practitioner",
        "motivated", "dumb", "hollow", "vault", "securely", "examining", "groove", "revelation", "pursuit", "delegation",
        "wires", "dictionaries", "mails", "backing", "greenhouse", "sleeps", "transparency", "dee", "travis", "endless",
        "figured", "orbit", "currencies", "niger", "bacon", "survivors", "positioning", "heater", "colony", "cannon",
        "circus", "promoted", "mae", "mel", "descending", "spine", "trout", "enclosed", "feat", "temporarily",
        "cooked", "thriller", "transmit", "fatty", "pressed", "frequencies", "scanned", "reflections", "hunger", "sic",
        "municipality", "detective", "surgeon", "cement", "experiencing", "fireplace", "endorsement", "planners", "disputes", "textiles",
        "missile", "intranet", "closes", "psychiatry", "persistent", "conf", "assists", "summaries", "glow", "auditor",
        "aquarium", "violin", "prophet", "bracket", "oxide", "oaks", "magnificent", "colleague", "promptly", "modems",
        "adaptation", "harmful", "paintball", "sexually", "enclosure", "dividend", "glucose", "phantom", "norm", "playback",
        "supervisors", "turtle", "distances", "absorption", "treasures", "warned", "neural", "ware", "fossil", "hometown",
        "badly", "transcripts", "apollo", "wan", "disappointed", "continually", "communist", "collectible", "handmade", "entrepreneurs",
        "robots", "creations", "jade", "scoop", "acquisitions", "foul", "keno", "earning", "mailman", "nested",
        "biodiversity", "excitement", "movers", "verbal", "blink", "presently", "seas", "workflow", "mysterious", "novelty",
        "tiles", "librarian", "subsidiaries", "switched", "pose", "fuzzy", "grams", "therapist", "budgets", "toolkit",
        "promising", "relaxation", "goat", "render", "carmen", "sen", "thereafter", "hardwood", "erotica", "temporal",
        "sail", "forge", "commissioners", "dense", "brave", "forwarding", "awful", "nightmare", "airplane", "reductions",
        "impose", "organisms", "telescope", "viewers", "asbestos", "enters", "pod", "savage", "advancement", "harassment",
        "willow", "resumes", "bolt", "gage", "throwing", "existed", "whore", "generators", "wagon", "barbie",
        "favour", "knock", "urge", "generates", "potatoes", "thorough", "replication", "inexpensive", "receptors", "peers",
        "optimum", "neon", "interventions", "quilt", "creature", "ours", "mounts", "internship", "lone", "refresh",
        "aluminium", "snowboard", "webcast", "evanescence", "subtle", "coordinated", "shipments", "stripes", "firmware", "cope",
        "shepherd", "cradle", "chancellor", "mambo", "lime", "kirk", "flour", "controversy", "legendary", "bool",
        "sympathy", "choir", "avoiding", "beautifully", "blond", "expects", "jumping", "fabrics", "antibodies", "polymer",
        "hygiene", "wit", "poultry", "virtue", "burst", "examinations", "surgeons", "bouquet", "immunology", "promotes",
        "mandate", "departmental", "spas", "corpus", "terminology", "gentleman", "fibre", "reproduce", "convicted", "shades",
        "jets", "indices", "roommates", "adware", "threatening", "spokesman", "activists", "frankfurt", "prisoner", "daisy",
        "encourages", "cursor", "assembled", "earliest", "donated", "stuffed", "restructuring", "insects", "terminals", "crude",
        "maiden", "simulations", "sufficiently", "examines", "viking", "myrtle", "bored", "cleanup", "yarn", "knit",
        "conditional", "mug", "crossword", "bother", "conceptual", "knitting", "attacked", "mating", "compute", "redhead",
        "arrives", "translator", "automobiles", "tractor", "continent", "ob", "unwrap", "fares", "longitude", "resist",
        "challenged", "hoped", "pike", "safer", "insertion", "instrumentation", "ids", "constraint", "groundwater", "touched",
        "strengthening", "cologne", "wishing", "ranger", "smallest", "insulation", "marsh", "scared", "theta", "infringement",
        "bent", "subjective", "monsters", "asylum", "stake", "cocktail", "outlets", "varieties", "arbor", "configurations",
        "poison"    ]
    private var contextBefore: String?
    private var contextAfter: String?
    private var selectedText: String?
    private var cachedSuggestions: [(String, [PredictionAction])]?

    func updateContext(before: String?, after: String?, selected: String?) {
        self.contextBefore = before
        self.contextAfter = after
        self.selectedText = selected
        self.cachedSuggestions = nil
    }

    func getSuggestions() -> [(String, [PredictionAction])] {
        if let cached = cachedSuggestions {
            return cached
        }

        let suggestions = makeSuggestions()
        cachedSuggestions = suggestions
        return suggestions
    }

    private func makeSuggestions() -> [(String, [PredictionAction])] {
        let (prefix, suffix) = extractCurrentWordContext()

        let prefixLower = prefix.lowercased()
        let suffixLower = suffix.lowercased()

        let matchingWords = Self.corpus.filter { word in
            let wordLower = word.lowercased()

            if !prefix.isEmpty && !suffix.isEmpty {
                return wordLower.hasPrefix(prefixLower) && wordLower.hasSuffix(suffixLower)
            } else if !prefix.isEmpty {
                return wordLower.hasPrefix(prefixLower)
            } else if !suffix.isEmpty {
                return wordLower.hasSuffix(suffixLower)
            } else {
                return true
            }
        }

        return Array(matchingWords.prefix(Self.maxSuggestions)).map { word in
            let displayWord = applySmartCapitalization(word: word, userPrefix: prefix, userSuffix: suffix)

            if !prefix.isEmpty && !suffix.isEmpty {
                // Insert middle part, move cursor past suffix, add space if at end
                let startIndex = displayWord.index(displayWord.startIndex, offsetBy: prefix.count)
                let endIndex = displayWord.index(displayWord.endIndex, offsetBy: -suffix.count)
                let insertText = String(displayWord[startIndex..<endIndex])
                var actions: [PredictionAction] = [.insert(insertText), .moveCursor(suffix.count)]

                // Check if we're at the very end of the document
                if let after = contextAfter, after.dropFirst(suffix.count).isEmpty {
                    actions.append(.insert(" "))
                    actions.append(.maybePunctuating(true))
                }

                return (displayWord, actions)
            } else if !prefix.isEmpty {
                // Remove prefix, add trailing space if no suffix
                let needsTrailingSpace = suffix.isEmpty
                let insertText = String(displayWord.dropFirst(prefix.count)) + (needsTrailingSpace ? " " : "")
                let actions: [PredictionAction] = needsTrailingSpace ? [.insert(insertText), .maybePunctuating(true)] : [.insert(insertText)]
                return (displayWord, actions)
            } else if !suffix.isEmpty {
                // Remove suffix
                let insertText = String(displayWord.dropLast(suffix.count))
                return (displayWord, [.insert(insertText)])
            } else {
                // No prefix/suffix to remove - check spacing
                let needsLeadingSpace = shouldAddLeadingSpace()
                let baseWord = applySmartCapitalization(word: word, userPrefix: prefix, userSuffix: suffix)
                let insertText = (needsLeadingSpace ? " " + baseWord : baseWord) + " "
                return (displayWord, [.insert(insertText), .maybePunctuating(true)])
            }
        }
    }

    /// Applies smart capitalization rules based on user input patterns
    ///
    /// Rules:
    /// - Users typically type lowercase, so preserve corpus capitalization unless user actively indicates otherwise
    /// - If user input is all lowercase → preserve corpus capitalization
    /// - If user uses capitals → apply their pattern, but only if it results in same or more capitals than corpus
    ///
    /// Examples with regular words:
    /// - "w|d" + "world" → "world" (all lowercase)
    /// - "W|d" + "world" → "World" (title case)
    /// - "Wo|d" + "world" → "World" (title case)
    /// - "W|D" + "world" → "WORLD" (all caps intent)
    /// - "WO|D" + "world" → "WORLD" (all caps)
    /// - "Wo|D" + "world" → "WorlD" (mixed case preserved)
    ///
    /// Examples with proper nouns:
    /// - "sh|" + "Shawn" → "Shawn" (preserve corpus caps)
    /// - "Sh|" + "Shawn" → "Shawn" (matches corpus)
    /// - "SH|" + "Shawn" → "SHAWN" (user wants all caps)
    /// - "SH|" + "should" → "SHOULD" (force all caps on regular word)
    ///
    /// Examples with acronyms:
    /// - "u|" + "USA" → "USA" (preserve corpus caps)
    /// - "U|" + "USA" → "USA" (preserve corpus caps)
    /// - "US|" + "USA" → "USA" (pattern matches corpus)
    /// - "us|" + "USA" → "USA" (preserve corpus caps)
    /// - "Us|" + "USA" → "USA" (preserve corpus caps)
    /// - "uS|" + "USA" → "USA" (preserve corpus caps)
    private func applySmartCapitalization(word: String, userPrefix: String, userSuffix: String) -> String {
        let userPattern = userPrefix + userSuffix

        // If user input is all lowercase, preserve corpus capitalization
        if userPattern.lowercased() == userPattern {
            return word
        }

        // Apply user's capitalization pattern to the full word
        let patternLength = userPattern.count
        let wordLength = word.count

        guard patternLength > 0 && wordLength > 0 else { return word }

        var result = word
        let wordArray = Array(word)
        let patternArray = Array(userPattern)

        // Apply capitalization pattern character by character
        for i in 0..<min(patternLength, wordLength) {
            let patternChar = patternArray[i]
            let wordChar = wordArray[i]

            if patternChar.isUppercase {
                result = String(result.prefix(i)) + String(wordChar).uppercased() + String(result.dropFirst(i + 1))
            } else {
                result = String(result.prefix(i)) + String(wordChar).lowercased() + String(result.dropFirst(i + 1))
            }
        }

        // If pattern is shorter than word, preserve remaining corpus capitalization
        // If user pattern shows "all caps intent" (multiple consecutive capitals), apply to whole word
        if patternLength < wordLength {
            let userCapitals = userPattern.filter { $0.isUppercase }.count
            let isAllCapsIntent = userCapitals == patternLength && userCapitals > 1

            if isAllCapsIntent {
                result = result.uppercased()
            }
            // Otherwise keep remaining characters as they were in corpus
        }

        return result
    }

    private func shouldAddLeadingSpace() -> Bool {
        guard let before = contextBefore, !before.isEmpty else {
            return false
        }

        let lastChar = before.last!

        // Add space after letters or punctuation that typically needs space after it
        return lastChar.isLetter || ".,!?:;".contains(lastChar)
    }

    private func extractCurrentWordContext() -> (prefix: String, suffix: String) {
        let prefix: String
        if let before = contextBefore {
            // Find the current word by walking backwards from the end until we hit a non-alpha character
            var wordStart = before.endIndex
            for index in before.indices.reversed() {
                let char = before[index]
                if char.isLetter {
                    wordStart = index
                } else {
                    break
                }
            }
            prefix = String(before[wordStart...])
        } else {
            prefix = ""
        }

        let suffix: String
        if let after = contextAfter {
            // Find the suffix by walking forward from the beginning until we hit a non-alpha character
            var wordEnd = after.startIndex
            for index in after.indices {
                let char = after[index]
                if char.isLetter {
                    wordEnd = after.index(after: index)
                } else {
                    break
                }
            }
            suffix = String(after[..<wordEnd])
        } else {
            suffix = ""
        }

        return (prefix, suffix)
    }
}
