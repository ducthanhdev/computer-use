mod controller;
mod models;
mod monitor;
mod ws;

use axum::extract::{Query, State};
use axum::http::StatusCode;
use axum::response::IntoResponse;
use axum::routing::{get, post};
use axum::{Json, Router};
use serde::{Deserialize, Serialize};
use std::net::SocketAddr;
use std::path::PathBuf;
use std::sync::Arc;
use tokio::sync::Mutex;
use tower_http::cors::{Any, CorsLayer};
use tower_http::services::ServeDir;
use crate::controller::SystemController;
use crate::models::SystemTelemetry;
use crate::monitor::TelemetryCollector;
use crate::ws::{ws_handler, SharedCollector};

#[derive(Clone)]
struct AppState {
    collector: SharedCollector,
    auth_pin: Option<String>,
}

#[derive(Deserialize)]
struct ProcessQuery {
    sort: Option<String>,
    limit: Option<usize>,
}

#[derive(Deserialize)]
struct ActionPayload {
    action: String,
}

#[derive(Serialize)]
struct ActionResponse {
    success: bool,
    message: String,
}

#[tokio::main]
async fn main() {
    tracing_subscriber::fmt()
        .with_env_filter("deskpulse_agent=info,tower_http=info")
        .init();

    let port = std::env::var("PORT")
        .ok()
        .and_then(|p| p.parse().ok())
        .unwrap_or(8765);

    let auth_pin = std::env::var("DESKPULSE_PIN").ok().filter(|s| !s.is_empty());

    let collector: SharedCollector = Arc::new(Mutex::new(TelemetryCollector::new()));
    let state = AppState {
        collector: collector.clone(),
        auth_pin,
    };

    let cors = CorsLayer::new()
        .allow_origin(Any)
        .allow_methods(Any)
        .allow_headers(Any);

    // Static assets fallback directory
    let static_dir = PathBuf::from(env!("CARGO_MANIFEST_DIR"))
        .parent()
        .unwrap()
        .join("static");

    let app = Router::new()
        .route("/ws", get({
            let col = collector.clone();
            move |ws| ws_handler(ws, col)
        }))
        .route("/api/status", get(get_status))
        .route("/api/processes", get(get_processes))
        .route("/api/action", post(post_action))
        .route("/api/ping", get(|| async { Json(serde_json::json!({ "status": "ok" })) }))
        .nest_service("/", ServeDir::new(&static_dir))
        .layer(cors)
        .with_state(state);

    let lan_ip = get_lan_ip().unwrap_or_else(|| "127.0.0.1".into());

    println!("==============================================================");
    println!("  🦀  DeskPulse Desktop Daemon (Rust Enterprise Edition)");
    println!("==============================================================");
    println!("  • Cổng (Port):     {port}");
    println!("  • Địa chỉ LAN:     http://{lan_ip}:{port}");
    println!("  • WebSocket URL:   ws://{lan_ip}:{port}/ws");
    println!("==============================================================");
    println!("  📱 FLUTTER MOBILE APP: Nhập địa chỉ: {lan_ip}:{port}");
    println!("==============================================================");

    let addr = SocketAddr::from(([0, 0, 0, 0], port));
    let listener = tokio::net::TcpListener::bind(addr).await.unwrap();
    axum::serve(listener, app).await.unwrap();
}

async fn get_status(State(state): State<AppState>) -> Json<SystemTelemetry> {
    let mut col = state.collector.lock().await;
    let data = col.sample();
    Json(data)
}

async fn get_processes(
    State(state): State<AppState>,
    Query(params): Query<ProcessQuery>,
) -> Json<serde_json::Value> {
    let limit = params.limit.unwrap_or(15);
    let sort_by_mem = params.sort.as_deref() == Some("mem");

    let mut col = state.collector.lock().await;
    let procs = col.get_processes(limit, sort_by_mem);
    Json(serde_json::json!({ "processes": procs }))
}

async fn post_action(
    State(_state): State<AppState>,
    Json(payload): Json<ActionPayload>,
) -> impl IntoResponse {
    let (success, message) = SystemController::handle_action(&payload.action);
    (
        StatusCode::OK,
        Json(ActionResponse { success, message }),
    )
}

fn get_lan_ip() -> Option<String> {
    let s = std::net::UdpSocket::bind("0.0.0.0:0").ok()?;
    s.connect("10.255.255.255:1").ok()?;
    let addr = s.local_addr().ok()?;
    let ip = addr.ip().to_string();
    if ip.starts_with("127.") {
        None
    } else {
        Some(ip)
    }
}
