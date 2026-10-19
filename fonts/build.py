# Notate Sans: Inter 4.1 (OFL) with the transcript-friendly forms frozen on, renamed, subset to Latin.
import sys
from fontTools.ttLib import TTFont
from fontTools import subset
from fontTools.feaLib.builder import addOpenTypeFeaturesFromString
src, out, weight, wname = sys.argv[1:5]
f = TTFont(src)
# freeze: cv05 tailed l, cv08 serifed capital I (I vs l vs 1 never confuse in a transcript), ss03 round quotes, cv11 single-storey a
feats = {'cv05', 'cv08', 'ss03', 'cv11'}
gsub = f['GSUB'].table
fl = gsub.FeatureList
want = {i for i, r in enumerate(fl.FeatureRecord) if r.FeatureTag in feats}
lookups = sorted({l for i in want for l in fl.FeatureRecord[i].Feature.LookupListIndex})
# apply those lookups as always-on: move them into 'calt' of every script/lang
calt = [i for i, r in enumerate(fl.FeatureRecord) if r.FeatureTag == 'calt']
for i in calt:
    feat = fl.FeatureRecord[i].Feature
    feat.LookupListIndex = sorted(set(feat.LookupListIndex) | set(lookups))
    feat.LookupCount = len(feat.LookupListIndex)
opts = subset.Options(); opts.layout_features = ['kern','liga','calt','case','tnum','ccmp','locl','mark','mkmk','frac','sups','subs']
opts.glyph_names = False; opts.notdef_outline = True; opts.name_IDs = ['*']
unis = list(range(0x20,0x7f))+list(range(0xa0,0x100))+list(range(0x2010,0x2030))+[0x2190,0x2191,0x2192,0x2193,0x2212,0x2248,0x2260,0x2264,0x2265,0x221a,0x221e,0x20ac]
s = subset.Subsetter(opts); s.populate(unicodes=unis); s.subset(f)
n = f['name']
ps = f"NotateSans-{wname}"
for rec in list(n.names):
    if rec.nameID in (1,16): rec.string = "Notate Sans"
    elif rec.nameID in (2,17): rec.string = wname if rec.nameID == 17 else ("Bold" if wname=="Bold" else "Regular")
    elif rec.nameID == 4: rec.string = f"Notate Sans {wname}"
    elif rec.nameID == 6: rec.string = ps
    elif rec.nameID == 3: rec.string = f"NotateSans;{wname}"
    elif rec.nameID == 0: rec.string = rec.toUnicode() + " Modified by Notate (tailed l, serifed I, round quotes, single-storey a)."
# legacy family split for the 4 weights
for rec in n.names:
    if rec.nameID == 1 and wname in ("Medium","SemiBold"): rec.string = f"Notate Sans {wname}"
f.save(out)
f.flavor='woff2'; f.save(out.replace('.ttf','.woff2'))
