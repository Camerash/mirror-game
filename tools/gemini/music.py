"""Draft a short piece of music with Lyria through the Gemini API. Usage:
    python3 -I tools/gemini/music.py prompt.txt out_basename [--final]
The model comes from tools/gemini/models.json: `music_draft` by default,
`music_final` only with --final (an owner-approved final). The audio part is
saved as out_basename plus the extension its MIME type names; any text part
(the model's notes or lyrics) goes to out_basename.txt."""
import base64, json, mimetypes, os, sys, urllib.request

args = sys.argv[1:]
final = "--final" in args
args = [a for a in args if a != "--final"]
prompt_file, out = args[0], args[1]
models = json.load(open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "models.json")))
model = models["music_final" if final else "music_draft"]
if not model:
    sys.exit("No model named for this use in models.json")
body = {"contents": [{"parts": [{"text": open(prompt_file).read()}]}]}
request = urllib.request.Request(
    f"https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent",
    data=json.dumps(body).encode(),
    headers={"Content-Type": "application/json", "x-goog-api-key": os.environ["GEMINI_API_KEY"]})
try:
    reply = json.load(urllib.request.urlopen(request, timeout=600))
except urllib.error.HTTPError as error:
    print("HTTP", error.code, error.read().decode()[:600]); sys.exit(1)
saved = False
texts = []
for part in reply["candidates"][0]["content"]["parts"]:
    if "inlineData" in part:
        mime = part["inlineData"].get("mimeType", "audio/mpeg")
        ext = {"audio/mpeg": ".mp3", "audio/mp3": ".mp3", "audio/wav": ".wav", "audio/x-wav": ".wav",
               "audio/L16": ".pcm"}.get(mime.split(";")[0], mimetypes.guess_extension(mime) or ".bin")
        data = base64.b64decode(part["inlineData"]["data"])
        open(out + ext, "wb").write(data)
        print(out + ext, model, mime, len(data))
        saved = True
    elif "text" in part:
        texts.append(part["text"])
if texts:
    open(out + ".txt", "w").write("\n".join(texts))
if not saved:
    print(json.dumps(reply)[:800]); sys.exit(1)
