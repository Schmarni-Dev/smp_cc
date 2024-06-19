pub mod protocol;
pub mod storage_cache;

use std::{cmp::min, collections::HashMap};

use axum::{
    extract::{
        ws::{Message, WebSocket},
        WebSocketUpgrade,
    },
    response::IntoResponse,
    routing::get,
    Router,
};
use color_eyre::eyre::eyre;
use futures::{stream::SplitSink, SinkExt, StreamExt};
use log::{debug, info};
use nucleo_matcher::{
    pattern::{AtomKind, CaseMatching, Normalization},
    Config,
};
use protocol::{ItemMoveOperation, ListItem, StorageMessage, StorageResponse};
use storage_cache::{Storage, StorageCluster};
use tokio::net::TcpListener;

#[tokio::main]
async fn main() -> color_eyre::Result<()> {
    color_eyre::install()?;
    pretty_env_logger::init();
    let app = Router::<()>::new()
        .route("/", get(|| async { "HellOwO OwOrld" }))
        .route("/storage_computer_ws", get(storage_connection));
    axum::serve(TcpListener::bind("127.0.0.1:6969").await?, app).await?;

    Ok(())
}

async fn storage_connection(ws: WebSocketUpgrade) -> impl IntoResponse {
    ws.on_upgrade(websocket_connection)
}

struct WsSender(SplitSink<WebSocket, Message>);
impl WsSender {
    async fn send(&mut self, resp: &StorageResponse) -> color_eyre::Result<()> {
        let str = serde_json::to_string(resp)?;
        debug!("sending json: {}", str);
        self.0.send(Message::Text(str)).await?;
        Ok(())
    }
}

async fn websocket_connection(ws: WebSocket) {
    let (tx, mut rx) = ws.split();
    let mut tx = WsSender(tx);
    let mut cluster = StorageCluster::<27>::default();
    while let Some(Ok(msg)) = rx.next().await {
        match msg {
            axum::extract::ws::Message::Text(text) => {
                debug!("recived msg: {}", text);
                let result: color_eyre::Result<()> =
                    match serde_json::from_str::<StorageMessage>(&text) {
                        Ok(msg) => handle_packet(msg, &mut tx, &mut cluster).await,
                        Err(err) => Err(eyre!("de error: {}\n with payload: {}", err, text)),
                    };

                if let Err(err) = result {
                    log::error!("{}", err);
                }
            }
            axum::extract::ws::Message::Binary(_bin) => {}
            axum::extract::ws::Message::Ping(_) => {}
            axum::extract::ws::Message::Pong(_) => {}
            axum::extract::ws::Message::Close(_) => {}
        }
    }
}

async fn handle_packet(
    packet: StorageMessage,
    sender: &mut WsSender,
    cluster: &mut StorageCluster<27>,
) -> color_eyre::Result<()> {
    match packet {
        StorageMessage::InsertRequest(item) => match cluster.find_space(item) {
            Some(slots) => {
                let ops = slots
                    .into_iter()
                    .map(|(net_name, slot)| ItemMoveOperation {
                        storage: net_name,
                        slot: slot + 1,
                    })
                    .collect();
                sender.send(&StorageResponse::Insert(ops)).await?;
            }
            None => {
                sender.send(&StorageResponse::NoSpace).await?;
            }
        },
        StorageMessage::PullRequest(mut item) => {
            let mut pulls = Vec::<ItemMoveOperation>::new();
            for storage in cluster.storages.iter() {
                for (slot, storage_item) in
                    (0..27).map(|i| (i, storage.items.get(i).and_then(|o| o.as_ref())))
                {
                    if let Some(stored_item) = storage_item {
                        if stored_item.ident == item.ident && stored_item.nbt_hash == item.nbt_hash
                        {
                            item.amount = min(item.amount - stored_item.amount as usize, 0);
                            pulls.push(ItemMoveOperation {
                                storage: storage.net_name.clone(),
                                slot: slot + 1,
                            })
                        }
                    }
                    if item.amount == 0 {
                        sender.send(&StorageResponse::Pull(pulls)).await?;
                        return Ok(());
                    }
                }
            }
        }
        StorageMessage::ListWithFilter(filter) => {
            let mut map = HashMap::<(&str, Option<u128>), ListItem>::new();
            for w in cluster
                .storages
                .iter()
                .flat_map(|s| s.items.iter())
                .filter_map(|v| v.as_ref())
            {
                map.entry((&w.ident, w.nbt_hash))
                    .or_insert_with(|| ListItem {
                        ident: w.ident.clone(),
                        name: w.name.clone(),
                        amount: 0,
                        max_stack_size: w.max_stack_size,
                        nbt_hash: w.nbt_hash.map(|v| format!("{:x}", v)),
                    })
                    .amount += w.amount as usize;
            }
            if let Some(filter) = filter {
                let mut matcher = nucleo_matcher::Matcher::new(Config::DEFAULT);
                let mut name_map = map
                    .into_values()
                    .map(|item| (item.name.clone(), item))
                    .collect::<HashMap<String, ListItem>>();
                let filterd_names = nucleo_matcher::pattern::Pattern::new(
                    &filter,
                    CaseMatching::Smart,
                    Normalization::Smart,
                    AtomKind::Fuzzy,
                )
                .match_list(name_map.keys().cloned(), &mut matcher);
                let mut filtered_list = Vec::new();
                for (val, _idk) in filterd_names {
                    if let Some(item) = name_map.remove(&val) {
                        filtered_list.push(item);
                    }
                }
                sender
                    .send(&StorageResponse::DisplayList(filtered_list))
                    .await?;
            } else {
                let mut values = map.into_values().collect::<Vec<_>>();
                values.sort_by(|i_1, i_2| i_2.amount.cmp(&i_1.amount));
                sender.send(&StorageResponse::DisplayList(values)).await?;
            }
        }
        StorageMessage::SyncStorages(storages) => {
            cluster.storages = storages
                .into_iter()
                .map(|s| Storage::<27> {
                    net_name: s.net_name,
                    items: s.items.map(Option::from),
                })
                .collect();
            debug!("done syncing Storages");
        }
        StorageMessage::AddedStorage(s) => cluster.storages.push(Storage::<27> {
            net_name: s.net_name,
            items: s.items.map(Option::from),
        }),
        StorageMessage::StorageRemoved(net_name) => {
            let index = (0..cluster.storages.len())
                .zip(cluster.storages.iter())
                .find_map(|(slot, storage)| (storage.net_name == net_name).then_some(slot));
            if let Some(i) = index {
                cluster.storages.swap_remove(i);
            }
        }
        StorageMessage::ItemPulled {
            storage: net_name,
            slot,
            amount,
        } => {
            let index = (0..cluster.storages.len())
                .zip(cluster.storages.iter())
                .find_map(|(slot, storage)| (storage.net_name == net_name).then_some(slot));
            if let Some(i) = index {
                if let Some(item) = cluster.storages[i].items[slot].as_mut() {
                    if min(item.amount - amount, 0) == 0 {
                        cluster.storages[i].items[slot].take();
                        return Ok(());
                    }
                    item.amount = min(item.amount - amount, 0);
                }
            }
        }
        StorageMessage::ItemPushed {
            storage: net_name,
            slot,
            item,
        } => {
            let index = (0..cluster.storages.len())
                .zip(cluster.storages.iter())
                .find_map(|(slot, storage)| (storage.net_name == net_name).then_some(slot));
            let Some(index) = index else {
                return Ok(());
            };
            match cluster.storages[index].items[slot].as_mut() {
                Some(i) => {
                    i.amount += item.amount;
                }
                None => {
                    cluster.storages[index].items[slot].replace(item);
                }
            };
        }
    };
    Ok(())
}
