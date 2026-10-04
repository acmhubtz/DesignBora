import websocket
import time
import sys
import os

TOKEN = os.environ.get("CUSTOMER_TOKEN")
ORDER_ID = "1"

if not TOKEN:
    print("Kosa: Weka kwanza CUSTOMER_TOKEN kwenye environment variable")
    sys.exit(1)

def on_message(ws, message):
    print(f"[IMEPOKEWA] {message}")

def on_error(ws, error):
    print(f"[ERROR] {error}")

def on_close(ws, close_status_code, close_msg):
    print("[MUUNGANIKO UMEFUNGWA]")

def on_open(ws):
    print("[MUUNGANIKO UMEFUNGULIWA] - Ninatuma CONNECT frame ya STOMP...")

    # STOMP CONNECT frame
    connect_frame = "CONNECT\naccept-version:1.2\nhost:localhost\n\n\x00"
    ws.send(connect_frame)
    time.sleep(1)

    # Subscribe kwenye topic ya order hii
    subscribe_frame = f"SUBSCRIBE\nid:sub-0\ndestination:/topic/chat/{ORDER_ID}\n\n\x00"
    ws.send(subscribe_frame)
    print(f"[NIME-SUBSCRIBE] kwenye /topic/chat/{ORDER_ID}")
    time.sleep(1)

    # Tuma ujumbe wa majaribio
    message_body = '{"message":"Habari, hii ni majaribio ya chat kupitia WebSocket"}'
    send_frame = f"SEND\ndestination:/app/chat.send/{ORDER_ID}\ncontent-type:application/json\n\n{message_body}\x00"
    ws.send(send_frame)
    print("[NIMETUMA UJUMBE]")

if __name__ == "__main__":
    websocket.enableTrace(False)
    ws_url = "ws://localhost:8080/ws"
    headers = [f"Authorization: Bearer {TOKEN}"]

    ws = websocket.WebSocketApp(
        ws_url,
        header=headers,
        on_open=on_open,
        on_message=on_message,
        on_error=on_error,
        on_close=on_close
    )

    ws.run_forever()
