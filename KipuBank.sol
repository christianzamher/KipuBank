// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title KipuBank 
 * @author Christian Zamora 
 * @notice Sistema de bóveda segura con mejoras de seguridad y funcionalidad
 * @dev Implementa patrones de seguridad avanzados y nuevas características
 */
contract KipuBank {
    /* ========== VARIABLES DE ESTADO ========== */
    uint256 public  WITHDRAWAL_LIMIT;
    uint256 public bankCap = 100 ether;
    uint256 public totalBankBalance;
    uint256 public totalDeposits;
    uint256 public totalWithdrawals;
    uint256 public withdrawalCooldown = 1 days;
    uint256 public interestRate = 0.05 ether;  // 5% anual

    mapping(address => uint256) public userVaults;
    mapping(address => uint256) private lastWithdrawalTime;
    mapping(address => uint256) private lastDepositTime;
    mapping(address => UserStats) private userStats;
    mapping(address => Transaction[]) private userTransactions;

    address public owner;
    bool private locked;

    /* ========== ESTRUCTURAS ========== */
    struct UserStats {
        uint256 totalDeposited;
        uint256 totalWithdrawn;
        uint256 netDeposit;
    }

    struct Transaction {
        uint256 amount;
        uint256 timestamp;
        bool isDeposit;
    }

    /* ========== EVENTOS ========== */
    event DepositMade(address indexed user, uint256 amount, uint256 newBalance);
    event WithdrawalMade(address indexed user, uint256 amount, uint256 remainingBalance);
    event BankCapUpdated(uint256 newCap);
    event WithdrawalLimitUpdated(uint256 newLimit);
    event EmergencyWithdrawal(address indexed user, uint256 amount);

    /* ========== ERRORES PERSONALIZADOS ========== */
    error BankCapacityExceeded(uint256 currentBalance, uint256 cap);
    error DepositMustBeGreaterThanZero();
    error WithdrawalExceedsLimit(uint256 requested, uint256 limit);
    error InsufficientVaultBalance(uint256 requested, uint256 available);
    error WithdrawalMustBeGreaterThanZero();
    error TransferFailed();
    error WithdrawalCooldownNotMet(uint256 lastWithdrawal, uint256 cooldown);
    error OnlyOwner();
    error InvalidAddress();

    /* ========== MODIFICADORES ========== */
    modifier nonReentrant() {
        require(!locked, "No reentrancy");
        locked = true;
        _;
        locked = false;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner");
        _;
    }

    modifier withinWithdrawalLimit(uint256 amount) {
        if (amount > WITHDRAWAL_LIMIT) {
            revert WithdrawalExceedsLimit(amount, WITHDRAWAL_LIMIT);
        }
        _;
    }

    /* ========== CONSTRUCTOR ========== */
    constructor(uint256 _withdrawalLimit) {
        WITHDRAWAL_LIMIT = _withdrawalLimit;
        owner = msg.sender;
    }

    /* ========== FUNCIONES EXTERNAS ========== */
        

    function deposit() external payable {
        if (msg.value == 0) {
            revert DepositMustBeGreaterThanZero();
        }

        if (totalBankBalance + msg.value > bankCap) {
            revert BankCapacityExceeded(totalBankBalance + msg.value, bankCap);
        }

        // Calcular interés para depósitos anteriores
        if (userVaults[msg.sender] > 0) {
            uint256 timeElapsed = block.timestamp - lastDepositTime[msg.sender];
            uint256 interest = (userVaults[msg.sender] * interestRate * timeElapsed) / (365 days * 100);
            userVaults[msg.sender] += interest;
            totalBankBalance += interest;
        }

        

        userVaults[msg.sender] += msg.value;
        totalBankBalance += msg.value;
        totalDeposits++;

        // Actualizar estadísticas
        userStats[msg.sender].totalDeposited += msg.value;
        userStats[msg.sender].netDeposit = userVaults[msg.sender];

        // Registrar transacción
        userTransactions[msg.sender].push(Transaction({
            amount: msg.value,
            timestamp: block.timestamp,
            isDeposit: true
        }));

        lastDepositTime[msg.sender] = block.timestamp;
        emit DepositMade(msg.sender, msg.value, userVaults[msg.sender]);
    }


    

    function withdraw(uint256 amount)
        external
        nonReentrant
        withinWithdrawalLimit(amount)
    {
        if (amount == 0) {
            revert WithdrawalMustBeGreaterThanZero();
        }

        if (userVaults[msg.sender] < amount) {
            revert InsufficientVaultBalance(amount, userVaults[msg.sender]);
        }

        if (block.timestamp < lastWithdrawalTime[msg.sender] + withdrawalCooldown) {
            revert WithdrawalCooldownNotMet(lastWithdrawalTime[msg.sender], withdrawalCooldown);
        }

        userVaults[msg.sender] -= amount;
        totalBankBalance -= amount;
        totalWithdrawals++;

        // Actualizar estadísticas
        userStats[msg.sender].totalWithdrawn += amount;
        userStats[msg.sender].netDeposit = userVaults[msg.sender];

        // Registrar transacción
        userTransactions[msg.sender].push(Transaction({
            amount: amount,
            timestamp: block.timestamp,
            isDeposit: false
        }));

        _safeTransfer(msg.sender, amount);
        lastWithdrawalTime[msg.sender] = block.timestamp;
        emit WithdrawalMade(msg.sender, amount, userVaults[msg.sender]);
    }

    function withdrawAll() external nonReentrant {
        uint256 amount = userVaults[msg.sender];
        require(amount > 0, "No balance to withdraw");

        userVaults[msg.sender] = 0;
        totalBankBalance -= amount;
        totalWithdrawals++;

        // Actualizar estadísticas
        userStats[msg.sender].totalWithdrawn += amount;
        userStats[msg.sender].netDeposit = 0;

        // Registrar transacción
        userTransactions[msg.sender].push(Transaction({
            amount: amount,
            timestamp: block.timestamp,
            isDeposit: false
        }));

        _safeTransfer(msg.sender, amount);
        lastWithdrawalTime[msg.sender] = block.timestamp;
        emit WithdrawalMade(msg.sender, amount, 0);
    }

    /* ========== FUNCIONES DE ADMINISTRACIÓN ========== */
    function setBankCap(uint256 _newCap) external onlyOwner {
        require(_newCap > totalBankBalance, "New cap must be greater than current balance");
        bankCap = _newCap;
        emit BankCapUpdated(_newCap);
    }

    function setWithdrawalLimit(uint256 _newLimit) external onlyOwner {
        WITHDRAWAL_LIMIT = _newLimit;
        emit WithdrawalLimitUpdated(_newLimit);
    }

    function emergencyWithdraw(uint256 amount) external onlyOwner {
        require(amount <= address(this).balance, "Insufficient balance");
        _safeTransfer(owner, amount);
        emit EmergencyWithdrawal(owner, amount);
    }

    /* ========== FUNCIONES DE CONSULTA ========== */
    function getUserVaultBalance(address user) external view returns (uint256) {
        return userVaults[user];
    }

    function getBankStats()
        external
        view
        returns (
            uint256 totalBalance,
            uint256 depositsCount,
            uint256 withdrawalsCount,
            uint256 remainingCapacity
        )
    {
        return (
            totalBankBalance,
            totalDeposits,
            totalWithdrawals,
            bankCap - totalBankBalance
        );
    }

    function getUserStats(address user) external view returns (UserStats memory) {
        return userStats[user];
    }

    function getUserTransactions(address user) external view returns (Transaction[] memory) {
        return userTransactions[user];
    }

    /* ========== FUNCIONES INTERNAS ========== */
    function _safeTransfer(address to, uint256 amount) private {
        require(to != address(0), "Invalid address");
        (bool success, ) = payable(to).call{value: amount}("");
        if (!success) {
            revert TransferFailed();
        }
    }
}