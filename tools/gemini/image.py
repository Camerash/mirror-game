"""Draft an image with Gemini. Usage:
    python3 -I tools/gemini/image.py prompt.txt out.png [ref.png ...] [--final] [--aspect 16:9]
The model comes from tools/gemini/models.json: `image_draft` by default,
`image_final` only with --final (an owner-approved final render)."""
import base64, json, mimetypes, os, sys, urllib.request

args = sys.argv[1:]
final = "--final" in args
aspect = "16:9"
if "--aspect" in args:
    aspect = args[args.index("--aspect") + 1]
    del args[args.index("--aspect"):args.index("--aspect") + 2]
args = [a for a in args if a != "--final"]
prompt_file, out, refs = args[0], args[1], args[2:]
models = json.load(open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "models.json")))
model = models["image_final" if final else "image_draft"]
if not model:
    sys.exit("No model named for this use in models.json")
parts = []
for ref in refs:
    mime = mimetypes.guess_type(ref)[0] or "image/png"
    parts.append({"inline_data": {"mime_type": mime, "data": base64.b64encode(open(ref, "rb").read()).decode()}})
parts.append({"text": open(prompt_file).read()})
body = {"contents": [{"parts": parts}],
        "generationConfig": {"responseModalities": ["IMAGE"], "imageConfig": {"aspectRatio": aspect, "imageSize": "2K"}}}
request = urllib.request.Request(
    f"https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent",
    data=json.dumps(body).encode(),
    headers={"Content-Type": "application/json", "x-goog-api-key": os.environ["GEMINI_API_KEY"]})
try:
    reply = json.load(urllib.request.urlopen(request, timeout=300))
except urllib.error.HTTPError as error:
    print("HTTP", error.code, error.read().decode()[:600]); sys.exit(1)
for part in reply["candidates"][0]["content"]["parts"]:
    if "inlineData" in part:
        data = base64.b64decode(part["inlineData"]["data"])
        open(out, "wb").write(data)
        print(out, model, len(data))
        break
else:
    print(json.dumps(reply)[:800]); sys.exit(1)
