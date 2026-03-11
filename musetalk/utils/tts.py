"""
Text-to-speech via Cartesia HTTP API.

Generates a WAV file from text, suitable for feeding into MuseTalk inference.
Requires CARTESIA_API_KEY environment variable.
"""

import json
import os
import wave
from urllib.request import Request, urlopen
from urllib.error import HTTPError

API_URL = "https://api.cartesia.ai/tts/bytes"
API_VERSION = "2024-06-10"

DEFAULT_MODEL = "sonic-2"
DEFAULT_VOICE_ID = "794f9389-aac1-45b6-b726-9d9369183238"
DEFAULT_SPEED = "normal"
SAMPLE_RATE = 16000  # MuseTalk expects 16kHz


def text_to_wav(
    text: str,
    output_path: str,
    voice_id: str = DEFAULT_VOICE_ID,
    model: str = DEFAULT_MODEL,
    speed: str = DEFAULT_SPEED,
    language: str = "en",
) -> str:
    """Convert text to a 16kHz mono WAV file using Cartesia TTS.

    Args:
        text: Text to synthesize.
        output_path: Path to write the output WAV file.
        voice_id: Cartesia voice ID.
        model: Cartesia model name.
        speed: Speech speed ("slowest", "slow", "normal", "fast", "fastest").
        language: Language code.

    Returns:
        Path to the generated WAV file.

    Raises:
        ValueError: If CARTESIA_API_KEY is not set or text is empty.
        RuntimeError: If the API call fails.
    """
    api_key = os.environ.get("CARTESIA_API_KEY", "")
    if not api_key:
        raise ValueError(
            "CARTESIA_API_KEY environment variable is not set. "
            "Get your API key at https://play.cartesia.ai/keys"
        )
    if not text or not text.strip():
        raise ValueError("Text cannot be empty")

    payload = json.dumps({
        "model_id": model,
        "transcript": text.strip(),
        "voice": {"mode": "id", "id": voice_id, "speed": speed},
        "output_format": {
            "container": "raw",
            "encoding": "pcm_s16le",
            "sample_rate": SAMPLE_RATE,
        },
        "language": language,
    })

    req = Request(
        API_URL,
        data=payload.encode("utf-8"),
        headers={
            "X-API-Key": api_key,
            "Cartesia-Version": API_VERSION,
            "Content-Type": "application/json",
        },
        method="POST",
    )

    try:
        with urlopen(req, timeout=60) as resp:
            pcm_data = resp.read()
    except HTTPError as e:
        body = e.read().decode("utf-8", errors="replace")
        raise RuntimeError(f"Cartesia API error ({e.code}): {body}") from e

    # Wrap raw PCM in a WAV file
    os.makedirs(os.path.dirname(output_path) or ".", exist_ok=True)
    with wave.open(output_path, "wb") as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)  # 16-bit
        wf.setframerate(SAMPLE_RATE)
        wf.writeframes(pcm_data)

    return output_path
