// Пример: как владелец вызывает вывод TON из Vault-контракта.
// Владелец — это ЛЮБОЙ ваш кошелёк (например, обычный TON Wallet),
// сам Vault сид-фразы не имеет и не требует — он лишь проверяет,
// что входящее сообщение пришло с адреса owner.

import { TonClient, WalletContractV4, internal, beginCell, Address, toNano } from "@ton/ton";
import { mnemonicToPrivateKey } from "@ton/crypto";

// ── Настройки ─────────────────────────────────────────────
const VAULT_ADDRESS = "EQ...ваш_адрес_vault_после_деплоя";
const WITHDRAW_TO = "EQ...куда_вывести";
const WITHDRAW_AMOUNT_TON = "1.5"; // сколько TON вывести из Vault
const OWNER_MNEMONIC = (process.env.OWNER_MNEMONIC ?? "").split(" "); // 24 слова владельца-кошелька
// ─────────────────────────────────────────────────────────

async function main() {
  const client = new TonClient({
    endpoint: "https://toncenter.com/api/v2/jsonRPC",
    apiKey: process.env.TONCENTER_API_KEY, // получить на https://toncenter.com
  });

  const keyPair = await mnemonicToPrivateKey(OWNER_MNEMONIC);
  const wallet = WalletContractV4.create({ workchain: 0, publicKey: keyPair.publicKey });
  const walletContract = client.open(wallet);

  // Тело сообщения Withdraw для контракта Vault.
  // opcode генерируется Tact автоматически при компиляции —
  // возьмите его из build/Vault/Vault.abi (поле "Withdraw" -> header).
  const withdrawBody = beginCell()
    .storeUint(0x_OPCODE_WITHDRAW, 32) // ← вставить реальный opcode из .abi после сборки
    .storeCoins(toNano(WITHDRAW_AMOUNT_TON))
    .storeAddress(Address.parse(WITHDRAW_TO))
    .endCell();

  const seqno = await walletContract.getSeqno();

  await walletContract.sendTransfer({
    seqno,
    secretKey: keyPair.secretKey,
    messages: [
      internal({
        to: Address.parse(VAULT_ADDRESS),
        value: toNano("0.05"), // газ на выполнение
        body: withdrawBody,
      }),
    ],
  });

  console.log("Withdraw-сообщение отправлено, ждите подтверждения в проводнике (tonscan.org)");
}

main().catch(console.error);
