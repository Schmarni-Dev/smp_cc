use crate::storage_cache::Item;

#[derive(serde::Serialize, serde::Deserialize, Clone, Debug)]
pub enum StorageMessage {
    InsertRequest(Item),
    PullRequest(RequestItem),
    ListWithFilter(Option<String>),
    SyncStorages(Vec<ProtoStorage>),
    AddedStorage(Box<ProtoStorage>),
    StorageRemoved(String),
    ItemPulled {
        storage: String,
        slot: usize,
        amount: u8,
    },
    ItemPushed {
        storage: String,
        slot: usize,
        item: Item,
    },
}
#[derive(serde::Serialize, serde::Deserialize, Clone, Debug)]
pub enum StorageResponse {
    Insert(Vec<ItemMoveOperation>),
    Pull(Vec<ItemMoveOperation>),
    DisplayList(Vec<ListItem>),
    NoSpace,
}
#[derive(serde::Serialize, serde::Deserialize, Clone, Debug)]
pub struct ItemMoveOperation {
    pub storage: String,
    pub slot: usize,
}
#[derive(serde::Serialize, serde::Deserialize, Clone, Debug)]
pub struct RequestItem {
    pub ident: String,
    pub amount: usize,
    #[serde(deserialize_with = "crate::storage_cache::hex_decode")]
    pub nbt_hash: Option<u128>,
    // enchantments: Vec<Enchantment>
}
#[derive(serde::Serialize, serde::Deserialize, Clone, Debug)]
pub struct ListItem {
    pub ident: String,
    pub name: String,
    pub amount: usize,
    pub max_stack_size: u8,
    /// String since i am not willing to put the hex conversion into serde
    pub nbt_hash: Option<String>

}

#[derive(serde::Serialize, serde::Deserialize, Clone, Debug)]
pub struct ProtoStorage {
    pub net_name: String,
    pub items: [Maybe<Item>; 27],
}

#[derive(serde::Serialize, serde::Deserialize, Clone, Debug)]
pub enum Maybe<T> {
    Some(T),
    None,
}

impl<T> From<Maybe<T>> for Option<T> {
    fn from(value: Maybe<T>) -> Self {
        use Maybe::None as N;
        use Maybe::Some as S;
        match value {
            S(v) => Self::Some(v),
            N => Self::None,
        }
    }
}
impl<T> From<Option<T>> for Maybe<T> {
    fn from(value: Option<T>) -> Self {
        use Option::None as N;
        use Option::Some as S;
        match value {
            S(v) => Self::Some(v),
            N => Self::None,
        }
    }
}
