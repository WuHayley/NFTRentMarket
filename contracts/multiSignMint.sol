// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
// pragma experimental "ABIEncoderV2";

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";


interface IMultiSigWallet{

    function _addMinter(address _account) external; 
    function removeMinter(address _account) external;
    
    function signMintTx(uint MintId) external;

    // function managerMint(IERC20 _addr,uint _amount) external returns(bool);
    function mint(address _to, uint256 _amount) external;

}

contract MetaOneToken is IMultiSigWallet,Ownable, ERC20 {

    using SafeMath for uint256;

    uint256 constant E18 = 10**18;
    uint256 public constant MAX_TOTAL_TOKEN_SUPPLY = 1000000000*E18;

    mapping(address => bool) private _minters;     // 是否有铸造权？

    // 最少需要集齐3个签名数量
    uint constant MIN_SIGNATURES = 3;
    // mint交易所引
    uint private MintId;
    	
	// 交易结构
    struct MintTx {
		// 发起者
        address from;
		// 接受者
        address to;
		// 转账数量
        uint amount;
		// 签名数量
        uint8 signatureCount;
		// 签名详情
        mapping (address => uint8) signatures;
    }
    
	// 交易字典（交易ID-> tx）
    mapping (uint => MintTx) private MintTxs;
	// pending队列中的交易列表
    uint[] private pendingMintTxs;

    event DepositFunds(address from, uint amount);
    event TransferFunds(address to, uint amount);
	
	// 创建交易事件
    event MintCreated(
        address from,
        address to,
        uint amount,
        uint MintId
    );
    

    // event MinterAdded(address indexed account);
    // event MinterRemoved(address indexed account);

    modifier onlyMinter() {
        require(isMinter(msg.sender), "Only minter can call");
        _;
    }

    constructor() ERC20("MetaOne", "MT1") {
        // The owner is the default minter
        _addMinter(msg.sender);
    }


    /**
     * @dev Add a new minter.
     * @param _account Address of the minter
     */
    function addMinter(address _account) public onlyOwner {
        _addMinter(_account);
    }

    /**
     * @dev Remove a minter.
     * @param _account Address of the minter
     */
    function removeMinter(address _account) public override onlyOwner {
        _removeMinter(_account);
    }

    /**
     * @dev Renounce to be a minter.
     */
    function renounceMinter() public {
        _removeMinter(msg.sender);
    }

    function _beforeTokenTransfer (
        address from,
        address to,
        uint256 amount
    )internal virtual override{
        super._beforeTokenTransfer(from, to, amount);
        require(to != address(this));
    }

    // 签名（入参 交易ID）
    function signMintTx(uint _MintId) public override {
        require(_minters[msg.sender] == true,"Only minters can sign the tx");
        MintTx storage mintTx = MintTxs[_MintId];
        require(address(0) != mintTx.from);
        require(msg.sender != mintTx.from);
        require(mintTx.signatures[msg.sender]!=1);
        mintTx.signatures[msg.sender] = 1;
        mintTx.signatureCount++;
        
		// 如果签名数达到 MIN_SIGNATURES
        if(mintTx.signatureCount >= MIN_SIGNATURES){
			// 给地址 to 铸造 amount数
            mint(mintTx.to, mintTx.amount);

			// 触发转账成功事件
            // emit TransferFunds(transaction.to, transaction.amount);
			// 将此笔交易从pending队列中移除
            deleteMintTx(MintId);
        }
    }

    /**
     * @dev Mint new tokens.
     * @param _to Address to send the newly minted tokens
     * @param _amount Amount of tokens to mint
     */
    // function mint(address _to, uint256 _amount) public onlyMinter {
    //     require(totalSupply().add(_amount) <= MAX_TOTAL_TOKEN_SUPPLY, "Exceed max total supply");
    //     _mint(_to, _amount);
    // }

    function mint(address _to, uint256 _amount) public  override {
        require(_minters[msg.sender] == true,"Only minters can sign the tx");
        require(totalSupply().add(_amount) <= MAX_TOTAL_TOKEN_SUPPLY, "Exceed max total supply");
        _mint(_to, _amount);
    }

    /**
     * @dev Destroys tokens.
     * @param _value Amount of tokens to burn
     */
    function burn(uint256 _value) public {
        _burn(msg.sender, _value);
    }

    /**
     * @dev Return if the `_account` is a minter or not.
     * @param _account Address to check
     * @return True if the `_account` is minter
     */
    function isMinter(address _account) public view returns (bool) {
        return _minters[_account];
    }

    /**
     * @dev Add a new minter.
     * @param _account Address of the minter
     */
    function _addMinter(address _account) public override onlyMinter{
        _minters[_account] = true;
        // emit MinterAdded(_account);
    }

    /**
     * @dev Remove a minter.
     * @param _account Address of the minter
     */
    function _removeMinter(address _account) private {
        _minters[_account] = false;
        // emit MinterRemoved(_account);
    }

    // 移除交易
    function deleteMintTx(uint _MintId) internal {
        uint8 replace = 0;
        for(uint i = 0; i< pendingMintTxs.length; i++){
            if(1==replace){
                pendingMintTxs[i-1] = pendingMintTxs[i];  //后一个值替换前一个
            }else if(_MintId == pendingMintTxs[i]){   //找到要移除的ID，标记1
                replace = 1;
            }
        } 
        delete pendingMintTxs[pendingMintTxs.length - 1];
        // pendingTransactions.length--;
        delete MintTxs[_MintId];
    }


}




