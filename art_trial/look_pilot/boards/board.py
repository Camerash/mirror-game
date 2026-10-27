"""Restyle a reference render with a Gemini image model. Usage: board.py model ref.png prompt.txt out.png"""
import base64, json, os, sys, urllib.request
model, ref, prompt_file, out = sys.argv[1:5]
prompt = open(prompt_file).read()
body = {
    "contents": [{"parts": [
        {"inline_data": {"mime_type": "image/png", "data": base64.b64encode(open(ref, "rb").read()).decode()}},
        {"text": prompt},
    ]}],
    "generationConfig": {"responseModalities": ["IMAGE"], "imageConfig": {"aspectRatio": "16:9", "imageSize": "2K"}},
}
request = urllib.request.Request(
    f"https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent",
    data=json.dumps(body).encode(), headers={"Content-Type": "application/json", "x-goog-api-key": os.environ["GEMINI_API_KEY"]})
try:
    reply = json.load(urllib.request.urlopen(request, timeout=300))
except urllib.error.HTTPError as error:
    print("HTTP", error.code, error.read().decode()[:600]); sys.exit(1)
for part in reply["candidates"][0]["content"]["parts"]:
    if "inlineData" in part:
        data = base64.b64decode(part["inlineData"]["data"])
        open(out, "wb").write(data)
        print(out, len(data), part["inlineData"].get("mimeType"))
        break
else:
    print(json.dumps(reply)[:800]); sys.exit(1)
