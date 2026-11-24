use axum::extract::ws::{Message, WebSocket, WebSocketUpgrade};
use axum::response::IntoResponse;
use futures_util::{SinkExt, StreamExt};
use std::sync::Arc;
use std::time::Duration;
use tokio::sync::Mutex;
use tracing::{info, warn};

use crate::controller::SystemController;
use crate::models::{ClientCommand, ServerEvent};
use crate::monitor::TelemetryCollector;

pub type SharedCollector = Arc<Mutex<TelemetryCollector>>;

pub async fn ws_handler(
    ws: WebSocketUpgrade,
    collector: SharedCollector,
) -> impl IntoResponse {
    ws.on_upgrade(move |socket| handle_socket(socket, collector))
}

async fn handle_socket(socket: WebSocket, collector: SharedCollector) {
    info!("New Flutter WebSocket connection established");
    let (mut sender, mut receiver) = socket.split();

    // 1. Spawning a sender task that streams telemetry every 800ms
    let collector_clone = collector.clone();
    let mut ticker = tokio::time::interval(Duration::from_millis(800));

    let mut send_task = tokio::spawn(async move {
        loop {
            ticker.tick().await;

            let telemetry = {
                let mut col = collector_clone.lock().await;
                col.sample()
            };

            let event = ServerEvent::Telemetry(telemetry);
            if let Ok(json_str) = serde_json::to_string(&event) {
                if let Err(e) = sender.send(Message::Text(json_str)).await {
                    warn!("WebSocket client disconnected: {e}");
                    break;
                }
            }
        }
    });

    // 2. Main receiver task reading incoming commands from Flutter
    let mut recv_task = tokio::spawn(async move {
        while let Some(Ok(msg)) = receiver.next().await {
            match msg {
                Message::Text(text) => {
                    if let Ok(cmd) = serde_json::from_str::<ClientCommand>(&text) {
                        match cmd {
                            ClientCommand::Action { action } => {
                                let (success, message) = SystemController::handle_action(&action);
                                info!("Action '{action}' executed: success={success}, msg={message}");
                            }
                            ClientCommand::MouseMove { dx, dy } => {
                                SystemController::handle_mouse_move(dx, dy);
                            }
                            ClientCommand::MouseClick { button } => {
                                SystemController::handle_mouse_click(&button);
                            }
                            ClientCommand::MouseScroll { dy } => {
                                SystemController::handle_mouse_scroll(dy);
                            }
                            ClientCommand::KeyPress { key: _ } => {
                                // Keyboard emulation
                            }
                            ClientCommand::Ping => {
                                // Ping / Pong handled
                            }
                        }
                    } else {
                        warn!("Unrecognized JSON command: {text}");
                    }
                }
                Message::Ping(_) => {
                    // Axum handles pong automatically
                }
                Message::Close(_) => {
                    info!("WebSocket client sent close frame");
                    break;
                }
                _ => {}
            }
        }
    });

    // If either task finishes (disconnect/error), abort the other
    tokio::select! {
        _ = (&mut send_task) => recv_task.abort(),
        _ = (&mut recv_task) => send_task.abort(),
    };

    info!("WebSocket connection closed");
}
