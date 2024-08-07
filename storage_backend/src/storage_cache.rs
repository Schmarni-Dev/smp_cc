use std::{collections::HashMap, fmt};

use log::info;
use serde::{
    de::{self, Visitor},
    Deserializer,
};

#[derive(Default)]
pub struct StorageCluster<const SLOTS: usize> {
    pub storages: HashMap<String, Storage<SLOTS>>,
}

impl<const T: usize> StorageCluster<T> {
    pub fn find_space(&self, item: &Item) -> Option<Vec<(String, usize)>> {
        let mut amount = item.amount;
        let mut slots = Vec::<(String, usize)>::new();
        for storage in self.storages.values() {
            for (slot, storage_item) in
                (0..T).map(|i| (i, storage.items.get(i).and_then(|o| o.as_ref())))
            {
                let Some(storage_item) = storage_item else {
                    info!("none");
                    slots.push((storage.net_name.clone(), slot));
                    return Some(slots);
                };
                if !(storage_item.ident == item.ident && storage_item.nbt_hash == item.nbt_hash) {
                    continue;
                }
                info!("same item");
                info!("in storage: {}", storage_item.ident);
                info!("out of storage: {}", storage_item.ident);
                if storage_item.amount < storage_item.max_stack_size {
                    amount = amount.saturating_sub(
                        storage_item
                            .max_stack_size
                            .saturating_sub(storage_item.amount),
                    );
                    slots.push((storage.net_name.clone(), slot));
                    if amount == 0 {
                        return Some(slots);
                    };
                }
            }
        }
        if slots.is_empty() {
            None
        } else {
            Some(slots)
        }
    }
}
struct HexU128Visitor;

impl<'de> Visitor<'de> for HexU128Visitor {
    type Value = u128;

    fn expecting(&self, formatter: &mut fmt::Formatter) -> fmt::Result {
        formatter.write_str("an u128 formatted as a Hex number")
    }

    fn visit_str<E>(self, v: &str) -> Result<Self::Value, E>
    where
        E: de::Error,
    {
        u128::from_str_radix(v, 16).map_err(|err| E::custom(err))
    }
    fn visit_string<E>(self, v: String) -> Result<Self::Value, E>
    where
        E: de::Error,
    {
        u128::from_str_radix(&v, 16).map_err(|err| E::custom(err))
    }
}
pub fn hex_decode<'de, D: Deserializer<'de>>(de: D) -> Result<Option<u128>, D::Error> {
    de.deserialize_str(HexU128Visitor).map(Some)
}

pub struct Storage<const SLOTS: usize> {
    pub net_name: String,
    pub items: [Option<Item>; SLOTS],
}

#[derive(serde::Serialize, serde::Deserialize, Clone, Debug)]
pub struct Item {
    pub ident: String,
    pub name: String,
    pub amount: u8,
    pub max_stack_size: u8,
    #[serde(default)]
    #[serde(deserialize_with = "hex_decode")]
    pub nbt_hash: Option<u128>,
    // enchantments: Vec<Enchantment>
}
// pub struct Enchantment {
//     ident: String,
//     name: String,
//     level: u8,
// }
