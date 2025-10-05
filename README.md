# KipuBank

KipuBank es un contrato inteligente de bóveda segura en Ethereum que permite a los usuarios depositar y retirar ETH bajo reglas estrictas de seguridad y límites configurables.

## Características

- Depósitos y retiros de ETH con límites por transacción y un tope global del banco.
- Cálculo de intereses sobre depósitos.
- Cooldown entre retiros para mayor seguridad.
- Registro de estadísticas y transacciones por usuario.
- Funciones administrativas para el owner.
- Protección contra ataques de reentrancia.
- Errores personalizados y eventos para trazabilidad.

## Despliegue

1. **Compila el contrato con Solidity 0.8.19.**
2. **Despliega el contrato pasando el límite de retiro por transacción (en wei) como parámetro del constructor.**
   - Ejemplo: Para un límite de 1 ETH, usa `1000000000000000000`.
3. **El owner será la cuenta que despliega el contrato.**

## Interacción

- **deposit()**: Deposita ETH en tu bóveda personal.
- **withdraw(uint256 amount)**: Retira hasta el límite permitido y respetando el cooldown.
- **withdrawAll()**: Retira todo tu saldo disponible.
- **getUserVaultBalance(address user)**: Consulta el saldo de un usuario.
- **getBankStats()**: Consulta estadísticas globales del banco.
- **getUserStats(address user)**: Consulta estadísticas personales.
- **getUserTransactions(address user)**: Consulta el historial de transacciones de un usuario.
- **setBankCap(uint256 newCap)**: (Solo owner) Cambia el tope global del banco.
- **setWithdrawalLimit(uint256 newLimit)**: (Solo owner) Cambia el límite de retiro por transacción.
- **emergencyWithdraw(uint256 amount)**: (Solo owner) Retira fondos de emergencia.

## Despliegue en testnet

1. Selecciona una testnet en Remix (por ejemplo, Sepolia o Goerli).
2. Conecta tu wallet (MetaMask).
3. Despliega el contrato y guarda la dirección.
4. Verifica el código en el block explorer correspondiente.

## Dirección del contrato desplegado

> 0x4E4822ab6398474Ba0c844E6F6ecc43500C698db

---

## Licencia

MIT
