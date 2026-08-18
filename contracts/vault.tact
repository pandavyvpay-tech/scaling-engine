import "@stdlib/deploy";

// ─────────────────────────────────────────────────────────────
//  Сообщения, которые понимает контракт
// ─────────────────────────────────────────────────────────────

// Вывести TON на произвольный адрес
message Withdraw {
    amount: Int as coins;
    to: Address;
}

// Вывести весь баланс (кроме резерва на storage fee) на произвольный адрес
message WithdrawAll {
    to: Address;
}

// Отправить NFT, которым владеет этот контракт, на другой адрес
// (контракт должен быть текущим owner'ом NFT-айтема)
message SendNft {
    nftAddress: Address;
    newOwner: Address;
    forwardAmount: Int as coins; // сколько TON приложить к переводу NFT (обычно ~0.05-0.1)
}

// Сменить владельца контракта
message ChangeOwner {
    newOwner: Address;
}

// Стандартное сообщение TEP-62 для перевода NFT-айтема
message(0x5fcc3d14) NftTransfer {
    queryId: Int as uint64;
    newOwner: Address;
    responseDestination: Address;
    customPayload: Cell?;
    forwardAmount: Int as coins;
    forwardPayload: Slice as remaining;
}

// ─────────────────────────────────────────────────────────────
//  Контракт
// ─────────────────────────────────────────────────────────────

contract Vault with Deployable {

    owner: Address;

    init(owner: Address) {
        self.owner = owner;
    }

    // Просто принимаем TON без какой-либо логики (депозит)
    receive() {
        // пусто — комиссия минимальна, TON просто зачисляется на баланс
    }

    receive("deposit") {
        // то же самое, но с явным комментарием во входящей транзакции
    }

    // Вывод конкретной суммы TON
    receive(msg: Withdraw) {
        require(sender() == self.owner, "Vault: not owner");
        require(msg.amount > 0, "Vault: amount must be positive");

        send(SendParameters{
            to: msg.to,
            value: msg.amount,
            mode: SendIgnoreErrors,
            body: "withdraw".asComment(),
        });
    }

    // Вывод всего баланса (контракт сам оставляет себе минимальный резерв на storage fee)
    receive(msg: WithdrawAll) {
        require(sender() == self.owner, "Vault: not owner");

        send(SendParameters{
            to: msg.to,
            value: 0,
            mode: SendRemainingBalance | SendIgnoreErrors,
            body: "withdraw all".asComment(),
        });
    }

    // Отправка NFT, принадлежащего этому контракту
    receive(msg: SendNft) {
        require(sender() == self.owner, "Vault: not owner");
        require(msg.forwardAmount > 0, "Vault: forwardAmount must cover gas");

        send(SendParameters{
            to: msg.nftAddress,
            value: msg.forwardAmount,
            mode: SendIgnoreErrors,
            body: NftTransfer{
                queryId: 0,
                newOwner: msg.newOwner,
                responseDestination: self.owner,
                customPayload: null,
                forwardAmount: 1, // 1 нанотон, чтобы новый владелец получил уведомление
                forwardPayload: emptySlice(),
            }.toCell(),
        });
    }

    // Смена владельца хранилища
    receive(msg: ChangeOwner) {
        require(sender() == self.owner, "Vault: not owner");
        self.owner = msg.newOwner;
    }

    // ── Геттеры ────────────────────────────────────────────

    get fun owner(): Address {
        return self.owner;
    }

    get fun balance(): Int {
        return myBalance();
    }
}
