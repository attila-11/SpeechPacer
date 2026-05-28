import asyncio
import os
from http import HTTPStatus

from websockets.exceptions import ConnectionClosed
from websockets.legacy.server import WebSocketServerProtocol, serve
from websockets.legacy.client import connect


DEEPGRAM_API_KEY = os.getenv("DEEPGRAM_API_KEY", "").strip()
HOST = os.getenv("HOST", "0.0.0.0")
PORT = int(os.getenv("PORT", "8765"))
LISTEN_PATH = "/listen"

DEEPGRAM_URL = (
    "wss://api.deepgram.com/v1/listen"
    "?encoding=linear16"
    "&sample_rate=16000"
    "&channels=1"
    "&language=en"
    "&filler_words=true"
    "&interim_results=true"
    "&model=nova-2"
)


async def relay_watch_to_deepgram(watch_ws: WebSocketServerProtocol, deepgram_ws) -> None:
    try:
      async for message in watch_ws:
          await deepgram_ws.send(message)
    except ConnectionClosed:
      pass
    finally:
      try:
          await deepgram_ws.close()
      except Exception:
          pass


async def relay_deepgram_to_watch(deepgram_ws, watch_ws: WebSocketServerProtocol) -> None:
    try:
      async for message in deepgram_ws:
          await watch_ws.send(message)
    except ConnectionClosed:
      pass
    finally:
      try:
          await watch_ws.close()
      except Exception:
          pass


async def handle_watch_connection(watch_ws: WebSocketServerProtocol, path: str) -> None:
    if path != LISTEN_PATH:
        await watch_ws.close(code=1008, reason="Invalid path")
        return

    if not DEEPGRAM_API_KEY:
        await watch_ws.close(code=1011, reason="Missing DEEPGRAM_API_KEY")
        return

    print(f"[proxy] watch connected path={path}")

    try:
        async with connect(
            DEEPGRAM_URL,
            extra_headers={"Authorization": f"Token {DEEPGRAM_API_KEY}"},
        ) as deepgram_ws:
            print("[proxy] connected to Deepgram")

            watch_task = asyncio.create_task(relay_watch_to_deepgram(watch_ws, deepgram_ws))
            deepgram_task = asyncio.create_task(relay_deepgram_to_watch(deepgram_ws, watch_ws))

            done, pending = await asyncio.wait(
                [watch_task, deepgram_task],
                return_when=asyncio.FIRST_COMPLETED,
            )

            for task in pending:
                task.cancel()
    except Exception as err:
        print(f"[proxy] Deepgram connection failed: {err}")
        try:
            await watch_ws.close(code=1011, reason="Deepgram proxy failure")
        except Exception:
            pass
    finally:
        print("[proxy] watch disconnected")


async def process_http_request(path, request_headers):
    if path == "/" or path == "/health":
        body = b"ok"
        headers = [
            ("Content-Type", "text/plain; charset=utf-8"),
            ("Content-Length", str(len(body))),
        ]
        return HTTPStatus.OK, headers, body
    return None


async def main() -> None:
    print(f"[proxy] starting ws://{HOST}:{PORT}{LISTEN_PATH}")
    async with serve(handle_watch_connection, HOST, PORT, process_request=process_http_request):
        await asyncio.Future()


if __name__ == "__main__":
    asyncio.run(main())
