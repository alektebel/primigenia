"""Classification of Primigenia's EXISTING creatures (19) and flora (20), 2026-11-21 (brief docs/briefs/trophic-web.md step 1).
Level, role and habitats are the chair's reading of niche.diet/habitat in lore/creatures/*.json and gameplay/habitats in lore/flora/*.json.
This is the single source; foodweb.py writes it into lore/foodweb/primigenia.json and into the optional niche.trophic/niche.role fields."""
H = ["meadow", "forest", "shore", "shallows", "caves", "spring", "highlands", "vents"]
LEVELS = ["producer", "primary_consumer", "secondary_consumer", "tertiary_consumer", "apex_predator", "scavenger", "decomposer", "parasite", "omnivore"]
# id: (level, role, habitats, defended)
CREATURES = {
 "rondo": ("primary_consumer", "grazer", ["meadow", "spring"]),
 "zanco": ("primary_consumer", "grazer", ["highlands"]),
 "coloso": ("primary_consumer", "browser", ["shore", "spring"]),
 "zancuda": ("primary_consumer", "grazer", ["shore", "meadow"]),
 "sosa": ("primary_consumer", "algae_scraper", ["vents", "caves"]),
 "corona": ("primary_consumer", "filter_feeder", ["caves", "shallows"]),
 "sifon": ("primary_consumer", "filter_feeder", ["shallows", "caves"]),
 "cuarteta": ("secondary_consumer", "small_predator", ["shallows"]),
 "brujula": ("secondary_consumer", "small_predator", ["shore", "shallows"]),
 "acechalunas": ("secondary_consumer", "small_predator", ["highlands", "forest", "caves"]),
 "merodeador": ("tertiary_consumer", "mid_predator", ["forest", "highlands", "caves", "meadow"]),
 "garfio": ("tertiary_consumer", "mid_predator", ["meadow", "spring", "shore", "highlands"]),
 "espinodo": ("tertiary_consumer", "mid_predator", ["highlands", "meadow"]),
 "el_resoplido": ("scavenger", "scavenger", ["vents", "highlands", "caves"]),
 "babosa": ("decomposer", "detritivore", ["forest", "caves", "vents", "highlands", "meadow"]),
 "ecolumbre": ("omnivore", "omnivore", ["caves"]),
 "albinos": ("omnivore", "omnivore", ["forest", "caves"]),
 "alula": ("omnivore", "seed_disperser", ["forest", "highlands"]),
 "player_lineage": ("omnivore", "omnivore", ["meadow", "forest", "highlands", "shore", "spring"]),
}
# plants: id: (level, role, habitats, defended)
FLORA = {
 "caramillo": ("producer", "photosynthetic", ["meadow", "spring"], False),
 "ceniza_roja": ("producer", "photosynthetic", ["highlands", "vents"], False),
 "cinta_de_marea": ("producer", "photosynthetic", ["shore", "shallows", "caves"], False),
 "costra_de_azufre": ("producer", "chemosynthetic", ["vents"], False),
 "grama_de_ceniza": ("producer", "photosynthetic", ["highlands", "meadow"], False),
 "hierroflor": ("producer", "photosynthetic", ["highlands"], True),
 "lengua_de_lava": ("producer", "mixotroph", ["highlands"], False),
 "madre_de_agua": ("producer", "photosynthetic", ["spring"], False),
 "musgo_faro": ("producer", "photosynthetic", ["caves", "forest"], False),
 "nieblon": ("producer", "photosynthetic", ["forest"], False),
 "paja_dulce": ("producer", "photosynthetic", ["meadow"], False),
 "pan_de_humus": ("decomposer", "fungal_decomposer", ["forest", "caves"], False),
 "perlilla": ("producer", "photosynthetic", ["spring", "meadow"], False),
 "pluma_de_sombra": ("producer", "photosynthetic", ["forest", "caves"], False),
 "rodela_de_nieve": ("producer", "photosynthetic", ["highlands"], False),
 "salvisca": ("producer", "photosynthetic", ["shore"], False),
 "soga_de_dosel": ("producer", "photosynthetic", ["forest", "spring"], False),
 "trenza_de_ribera": ("producer", "photosynthetic", ["spring"], False),
 "velilla": ("producer", "photosynthetic", ["meadow", "spring"], False),
 "vetirroja": ("producer", "photosynthetic", ["meadow"], True),
}

RESOURCES = ["carrion", "detritus", "dung"]
# who eats what (existing species), from niche.diet / gameplay.food_for; new species get their edges from the ecologist seat (foodweb.py edges)
EATS = {
 "rondo": ["paja_dulce", "perlilla", "madre_de_agua", "soga_de_dosel", "grama_de_ceniza", "trenza_de_ribera"],
 "zanco": ["grama_de_ceniza"],
 "coloso": ["madre_de_agua", "soga_de_dosel"],
 "zancuda": ["cinta_de_marea", "paja_dulce"],
 "sosa": ["costra_de_azufre"],
 "corona": ["detritus"], "sifon": ["detritus"], "cuarteta": ["carrion"], "brujula": ["carrion"],
 "acechalunas": ["ecolumbre", "carrion"],
 "merodeador": ["rondo", "zanco", "carrion"],
 "garfio": ["rondo", "zanco", "zancuda", "albinos", "babosa", "carrion"],
 "espinodo": ["rondo", "zanco", "zancuda", "albinos", "babosa", "acechalunas", "carrion"],
 "el_resoplido": ["carrion", "costra_de_azufre"],
 "babosa": ["detritus", "pan_de_humus", "musgo_faro", "pluma_de_sombra", "grama_de_ceniza", "vetirroja", "ceniza_roja"],
 "ecolumbre": ["musgo_faro", "pan_de_humus"],
 "albinos": ["nieblon", "soga_de_dosel", "carrion"],
 "alula": ["nieblon", "soga_de_dosel"],
 "player_lineage": ["perlilla", "nieblon", "soga_de_dosel", "velilla", "paja_dulce", "madre_de_agua", "trenza_de_ribera", "carrion"],
 "pan_de_humus": ["detritus"],
 "lengua_de_lava": [],
}
NO_PREDATOR = {"coloso": "island giant (F27): adults have no predator; the carcass goes to scavengers", "player_lineage": "the player's lineage: not a prey species in the web"}
