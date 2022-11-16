// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity >=0.7.0 <0.9.0;
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
interface IVaultManager{

    //token租用状态。    for_rent:可租用。  rented：已出租(包括已生效和未生效)。    not_rentable:不可被租用。   empty:已withdraw/未deposit进来
    enum TokenState { for_rent, rented, not_rentable, empty }
    enum TokenType {ERC721,ERC1155}

    struct LendMsg{
        TokenType tkType;
        address NFTaddr;
        uint tokenID;  
        address lender;    //投资人
        bool renewable;    //可续租
        address rentCoinType;    //租金币种
        bool withdrawed;    //是否已withdraw
    }

    struct LenderEarnings{
        uint8 minimumLeaseTime;    //最少租用时长
        uint8 maximumLeaseTime;    //最大租用时长
        uint price;    // 租金：单个租期内的总价格
        uint8 gameBonus;    //奖励抽成百分比 ,默认为0
    }

    struct RentMsg{
        address renter;   //租用人
        // uint starttime;   //租用开始时间
        uint endtime;   //租用截止时间
    }

    struct AllMsg{
        TokenType tkType;
        address NFTaddr;
        uint tokenID;
        address lender;
        bool renewable;
        address rentCoinType;
        bool withdrawed;
        uint8 minimumLeaseTime;
        uint8 maximumLeaseTime;
        uint price;
        uint8 gameBonus;
        address renter;
        uint endtime;
    }

    // event Deposit(address _lender,TokenType _tkType,address _NFTaddr,uint _tokenID,bool _renewable,uint _coinIndex,uint8 _minimumLeaseTime,uint8 _maximumLeaseTime,uint _price,uint8 _gameBonus);
    // event Rent(uint _lendItemID,address _NFTaddr,uint _tokenID, address _renter,uint _endtime, uint8 _gameBonus,uint _rentTimes);
    // event Withdraw(uint _lendItemID,address _NFTaddr,uint _tokenID, address _lender);

    // event SetPlantformBonus(uint8 _plantformBonus);
    // event RenewableStatus(uint _lendItemID,bool _renewable);
    // event ResetDeposit(uint _lendItemID,uint8 _minimumLeaseTime,uint8 _maximumLeaseTime,uint _price,uint8 _gameBonus); 

    // function setPlantformBonus(uint8 _plantformBonus) external;

    // //租金单位为USDT/天.    bonus是百分比1～99之间的数字。 
    // function deposit(TokenType _tkType,address _NFTaddr,uint _tokenID,bool _renewable,uint _coinIndex,uint8 _minimumLeaseTime,uint8 _maximumLeaseTime,uint _price,uint8 _gameBonus) external returns(bool);

    // //是否可续租
    // function renewableStatus(uint _lendItemID,bool _renewable) external returns(bool);

    // //修改deposit信息    token没有被租赁时候才可以被修改
    // function resetDeposit(uint _lendItemID,uint8 _minimumLeaseTime,uint8 _maximumLeaseTime,uint _price,uint8 _gameBonus) external returns(bool);

    // function withdraw(uint _lendItemID) external;
    // function claim(address _coinType,uint _amount) external;

    // function getMyDepositsList() external returns(AllMsg[] memory);
    // function addRentCoin(address _rentCoin) external returns(bool);
    // function getLendItemMsg(uint _lendItemID) external view returns(AllMsg memory _AllMsg);

    // function balanceOfRentingGameTokenInContract(address _NFTaddr) external view returns(uint _balance);
    // function getTokenlendItemID(address _NFTaddr,uint _tokenID) external view returns(uint[] memory);


    // //调用后，租赁即时生效.   
    // function rent(uint _lendItemID,uint _rentTimes) external returns(bool);

    // function getMyRentsList() external returns(AllMsg[] memory);

    // function userclaim(IERC20 _addr,uint _amount) external returns(bool);


}
interface IMultiSigWallet{
    function addManager(address manager) external ;
    function removeManager(address manager) external;
    function signTransaction(uint transactionId) external;

    function managerClaim(IERC20 _addr,uint _amount) external returns(bool);

    // function grantRent(address _user,IERC20 _addr,uint _amount)external returns(bool);
}
library Calculate{
    using SafeMath for uint256;

    //计算租约到期时间
    function duetime(uint _rentTimes) internal view returns(uint){
        uint rentTimes = _rentTimes.mul(86400);  //按天          //计算租赁时长
        // uint rentTimes = _rentTimes.mul(60);   //按分钟
        return block.timestamp.add(rentTimes);
    }

    // //计算开始时间与当前时间的时间差
    function timeDifference() internal view returns(uint){
        uint current = block.timestamp;
        uint start = current%86400;
        uint difference;
        if(start <= 57600){
            difference = 57600 - start;
        }else{
            difference = 144000 - start;
        }
        return difference;
    }

    function starttime() internal view returns(uint){
        uint difference = timeDifference();
        return block.timestamp.add(difference);
    }

    function endtime(uint _rentTimes) internal view returns(uint){
        uint rentTimes = _rentTimes.mul(86400);  //按天
        uint start = starttime();
        return start.add(rentTimes);
    }


}

contract VaultManager is IVaultManager,IMultiSigWallet,OwnableUpgradeable{
    using SafeMath for uint256;

    uint8 public plantformBonus;

    address public admin;  

    function initialize() public initializer {
        __Ownable_init();   // 把_msgSender()设为 _owner
        plantformBonus = 5;
        admin = msg.sender;
        Owner = msg.sender;
    }


    address[] public rentCoin;

    uint lendItemID;   
    mapping(uint => LendMsg) public lendItem;  //租赁编号（lendItemID）与 租赁信息的映射
    mapping(uint => LenderEarnings) public earningItem;  //租赁编号（lendItemID）与 收益信息的映射 
    mapping(uint => RentMsg) public rentItem;  //租赁编号（lendItemID）与 租赁信息的映射

    //待注释掉！！！！！ 与ERC1155不兼容
    mapping(address => mapping(uint => uint)) public tokenItem721;  //ERC721token与 lendItemID的映射
    mapping(address => mapping(uint => uint[])) public tokenItem1155;

    mapping(address => mapping(address => uint)) public userBalance;  //player地址与（币种余额的映射）
    mapping(address => uint[]) private myDepositsList; //lender与lendItemID数组的映射
    mapping(address => uint[]) private myRentsList;  //renter与lendItemID数组的映射

    // constructor (uint8 _plantformBonus,address _admin,address[] memory _rentCoin){
    //     plantformBonus = _plantformBonus; 
    //     admin = _admin;
    //     rentCoin = _rentCoin;
    // }    

    ///重设平台分红百分比
    function setPlantformBonus(uint8 _plantformBonus) public  onlyOwner{
        plantformBonus = _plantformBonus;
        // emit SetPlantformBonus(_plantformBonus);
    }

    function addRentCoin(address _rentCoin) public  onlyOwner returns(bool){
        for(uint i = 0 ; i< rentCoin.length ; i++){
            require(_rentCoin != rentCoin[i],"The coin has been added!");
        } 
        rentCoin.push(_rentCoin);
        return true;
    }

    function userclaim(IERC20 _addr,uint _amount) public  returns(bool){
        require(userBalance[msg.sender][address(_addr)] >= _amount && _addr.balanceOf(address(this)) >= _amount,"Balance insufficient!");
        _addr.transfer(msg.sender,_amount);
        userBalance[msg.sender][address(_addr)] -= _amount;
        return true;
    }

   ///发起出租
    function deposit(TokenType _tkType,address _NFTaddr,uint _tokenID,bool _renewable,uint _coinIndex,uint8 _minimumLeaseTime,uint8 _maximumLeaseTime,uint _price,uint8 _gameBonus) public  returns(bool){
        if(_tkType == TokenType.ERC721){
            require(IERC721(_NFTaddr).ownerOf(_tokenID) == msg.sender ,"Depositer must be owner!" );
        }else{
            require(IERC1155(_NFTaddr).balanceOf(msg.sender,_tokenID) > 0 ,"Depositer must be owner!" );
        }

        //lendItemID与 LendMsg建立映射
        lendItem[lendItemID] = LendMsg({ 
            tkType : _tkType,
            NFTaddr : _NFTaddr,
            tokenID : _tokenID,
            lender : msg.sender,
            renewable : _renewable,
            rentCoinType : rentCoin[_coinIndex],
            withdrawed : false
        });

        //lendItemID与 LenderEarnings建立映射
        earningItem[lendItemID] = LenderEarnings({
            minimumLeaseTime : _minimumLeaseTime,
            maximumLeaseTime : _maximumLeaseTime,
            price : _price,
            gameBonus : _gameBonus
        });

        //建立token和lendItemID的映射
        //待注释掉！！！！！
        // tokenItem[_NFTaddr][_tokenID] = lendItemID;  
        if(_tkType == TokenType.ERC721){
            tokenItem721[_NFTaddr][_tokenID] = lendItemID;  
        }else{
            tokenItem1155[_NFTaddr][_tokenID].push(lendItemID);  
        }

        //lendItemID记录在lender
        myDepositsList[msg.sender].push(lendItemID);

        lendItemID = lendItemID.add(1);  //成功后序号+1

        if(_tkType == TokenType.ERC721){
            IERC721(_NFTaddr).transferFrom(msg.sender,address(this),_tokenID);   //token转移到此合约
        }else{
            IERC1155(_NFTaddr).safeTransferFrom(msg.sender,address(this),_tokenID,1,"0x00");   //token转移到此合约
        }

        // emit Deposit(msg.sender,_tkType,_NFTaddr,_tokenID,_renewable,_coinIndex,_minimumLeaseTime,_maximumLeaseTime,_price,_gameBonus);

        return true;
    }

    ///lender设置可否续租
    function renewableStatus(uint _lendItemID,bool _renewable) public  returns(bool){
        require(lendItem[_lendItemID].lender == msg.sender,"Only lender allowed");
        require(lendItem[_lendItemID].renewable != _renewable,"The state have been set"); //要与目前的状态不一样
        lendItem[_lendItemID].renewable = _renewable;
        // emit RenewableStatus(_lendItemID,_renewable);
        return true;
    }    

 
    //修改deposit信息    token没有被租赁时候才可以被修改
    function resetDeposit(uint _lendItemID,uint8 _minimumLeaseTime,uint8 _maximumLeaseTime,uint _price,uint8 _gameBonus) public  returns(bool){
        // (address _NFTaddr,uint _tokenID) = getLendItemToken(_lendItemID); 
        require(lendItem[_lendItemID].withdrawed == false,"Lender has withdrawed !");
        require(getTokenState(_lendItemID) != TokenState.rented,"NFT has been rented!");
        require(lendItem[_lendItemID].lender == msg.sender,"Only depositer allowed");

        earningItem[_lendItemID] = LenderEarnings({
            minimumLeaseTime : _minimumLeaseTime,
            maximumLeaseTime : _maximumLeaseTime,
            price : _price,
            gameBonus : _gameBonus
        });

        // emit ResetDeposit(_lendItemID, _minimumLeaseTime,_maximumLeaseTime, _price, _gameBonus);
        return true;
    }

    ///lender提取NFT 到自己的钱包
    function withdraw(uint _lendItemID) public  {
        // require(getTokenState(_lendItemID) != TokenState.rented && getTokenState(_lendItemID) != TokenState.empty,"NFT couldn't been withdrawed!");
        require(getTokenState(_lendItemID) != TokenState.rented && getTokenState(_lendItemID) != TokenState.empty,"NFT couldn't been withdrawed!");
        require(lendItem[_lendItemID].lender == msg.sender,"Only depositer allowed");

        // (address _NFTaddr,uint _tokenID) = getLendItemToken(_lendItemID);  
        address _NFTaddr = lendItem[_lendItemID].NFTaddr;
        uint _tokenID = lendItem[_lendItemID].tokenID;

        if(lendItem[_lendItemID].tkType == TokenType.ERC721){
            IERC721(_NFTaddr).safeTransferFrom(address(this),msg.sender,_tokenID);   //提取token
        }else{
            IERC1155(_NFTaddr).safeTransferFrom(address(this),msg.sender,_tokenID,1,"0x00");   //提取token
        }

        lendItem[_lendItemID].withdrawed = true;

        // emit Withdraw(_lendItemID,_NFTaddr,_tokenID, msg.sender);
    }

    //查看所有我的Deposit记录（包含正在进行中和已结束的）
    function getMyDepositsList() public  view returns(AllMsg[] memory){
        
        //list长度
        uint l = myDepositsList[msg.sender].length;

        //创建list数组
        AllMsg[] memory list= new AllMsg[](l); 

        //把所有我的lendItemID存入items数组
        for(uint i;i< l;i++){
            list[i] = getLendItemMsg(myDepositsList[msg.sender][i]);
        }
        return list;
    }
   

    //调用后，次日生效.  
    function rent(uint _lendItemID,uint _rentTimes) public  returns(bool){
        require(lendItem[_lendItemID].lender != msg.sender,"Sender is lender!");  //lender不可以租用
        require(getTokenState(_lendItemID) == TokenState.for_rent,"TokenState not allowed");
        require(_rentTimes>= earningItem[_lendItemID].minimumLeaseTime && _rentTimes<=earningItem[_lendItemID].maximumLeaseTime,"Out of range !");

        // IERC20(USDT).transferFrom(msg.sender,lendItem[_lendItemID].lender,earningItem[_lendItemID].price..mul(_rentTimes).mul(100-plantformBonus).div(100));  //支付租金
        // IERC20(USDT).transferFrom(msg.sender,admin,earningItem[_lendItemID].price..mul(_rentTimes).mul(plantformBonus).div(100));  //支付平台佣金

        IERC20(lendItem[_lendItemID].rentCoinType).transferFrom(msg.sender,address(this),earningItem[_lendItemID].price.mul(_rentTimes)); 

        // rentItem[_lendItemID] = RentMsg({   //添加租用信息
        //     renter : msg.sender,
        //     starttime : Calculate.starttime(),
        //     endtime: Calculate.endtime(_rentTimes)
        // });

        //记录msg.sender可claim的余额
        userBalance[msg.sender][lendItem[_lendItemID].rentCoinType] +=  earningItem[_lendItemID].price.mul(_rentTimes).mul(100-plantformBonus).div(100);
        
        //_lendItemID记录在renter
        myRentsList[msg.sender].push(_lendItemID);

        // emit Rent(_lendItemID,lendItem[_lendItemID].NFTaddr,lendItem[_lendItemID].tokenID,msg.sender,rentItem[_lendItemID].starttime,rentItem[_lendItemID].endtime,earningItem[_lendItemID].gameBonus,_rentTimes);

        return true;
    }

    function balanceOfRentsList(address _user) public  view returns(uint256) {
        return myRentsList[_user].length;
    }

    function getRentsList(address _user, uint256 _index, uint8 _len) public  view returns(
        AllMsg[] memory nfts,
        uint8 len
    ) {
        require(_len <= 100 && _len != 0);
        nfts = new AllMsg[](_len);
        len = 0;

        uint256 bal = balanceOfRentsList(_user);
        if (bal == 0 || _index >= bal) {
            return (nfts, len);
        }

        for (uint8 i = 0; i < _len; ++i) {
            nfts[i] = getLendItemMsg(myRentsList[_user][_index]);
            ++_index;
            ++len;
            if (_index >= bal) {
                return (nfts, len);
            }
        }
    }

    function renterOfERC721(address _NFTaddr,uint _tokenID) public  view returns(address) {
        uint _lendItemID = tokenItem721[_NFTaddr][_tokenID];
        return rentItem[_lendItemID].renter;
    }

    function erc721TokenOfRenterByIndex(address _renter, uint256 _index) public  view returns(uint256) {
        uint _lendItemID = myRentsList[_renter][_index];
        return lendItem[_lendItemID].tokenID;
    }

    function getMyRentsList() public  view returns(AllMsg[] memory){
         //list长度
        uint l = myRentsList[msg.sender].length;

        //创建list数组
        AllMsg[] memory list= new AllMsg[](l); 

        //把所有我的lendItemID存入items数组
        for(uint i;i< l;i++){
             list[i] = getLendItemMsg(myRentsList[msg.sender][i]);
        }
        return list;
    }

    //查询租赁item的所有信息
    function getLendItemMsg(uint _lendItemID) public  view returns(AllMsg memory _AllMsg){
        _AllMsg.tkType= lendItem[_lendItemID].tkType;
        _AllMsg.NFTaddr = lendItem[_lendItemID].NFTaddr;
        _AllMsg.tokenID = lendItem[_lendItemID].tokenID;
        _AllMsg.lender = lendItem[_lendItemID].lender;
        _AllMsg.renewable = lendItem[_lendItemID].renewable;
        _AllMsg.rentCoinType = lendItem[_lendItemID].rentCoinType;
        _AllMsg.minimumLeaseTime = earningItem[_lendItemID].minimumLeaseTime;
        _AllMsg.maximumLeaseTime = earningItem[_lendItemID].maximumLeaseTime;
        _AllMsg.price = earningItem[_lendItemID].price;
        _AllMsg.gameBonus = earningItem[_lendItemID].gameBonus;
        _AllMsg.renter = rentItem[_lendItemID].renter;
        _AllMsg.endtime = rentItem[_lendItemID].endtime;
    }


    ///NFT资产被租用状态
    function getTokenState(uint _lendItemID)internal view returns(TokenState){
        uint _endtime = rentItem[_lendItemID].endtime;
        TokenState _state;
   
        if(lendItem[_lendItemID].withdrawed == true){
            _state = TokenState.empty;  //token已被提走
        }else if(block.timestamp > _endtime && lendItem[_lendItemID].renewable == false && _endtime != 0){
            _state = TokenState.not_rentable;  //租期已到,不可续租
        }else if(block.timestamp < _endtime){
            _state = TokenState.rented;  //未到_endtime，状态为“rented”
        }else
        if((block.timestamp >= _endtime && lendItem[_lendItemID].renewable == true)|| _endtime == 0){
            _state = TokenState.for_rent;   //租期已到(可续租）/从未租用过
        } 
        return _state;
    }


    // 交易发起者
    address private Owner;
	// 签名者
    mapping (address => uint8) private managers;
	
    modifier isOwner{
        require(Owner == msg.sender);
        _;
    }

    modifier isManager{
        require(
            msg.sender == Owner || managers[msg.sender] == 1);
        _;
    }
    
	// 最少需要集齐3个签名数量
    uint constant MIN_SIGNATURES = 2;
	// 交易所引
    uint private transactionIdx;
	
	// 交易结构
    struct Transaction {
        IERC20 addr;
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
    mapping (uint => Transaction) private transactions;
	// pending队列中的交易列表
    uint[] private pendingTransactions;

    event DepositFunds(address from, uint amount);
    event TransferFunds(address to, uint amount);
	
	// 创建交易事件
    event TransactionCreated(
        address from,
        address to,
        uint amount,
        uint transactionId
        );
    
    function addManager(address manager) public override isOwner{
        managers[manager] = 1;
    }
    
    function removeManager(address manager) public override isOwner{
        managers[manager] = 0;
    }

    function managerClaim(IERC20 _addr,uint _amount) public override isManager returns(bool){
        transferTo(_addr,msg.sender,_amount);
        // _addr.transfer(msg.sender,_amount);
        return true;
    }

    function grantRent(address _user,IERC20 _addr,uint _amount)public isManager returns(bool){
        transferTo(_addr,_user,_amount);
        // _addr.transfer(_user,_amount);
        return true;
    }

    function transferTo(IERC20 _addr,address _to,  uint _amount) isManager public{
        require(_addr.balanceOf(address(this)) >= _amount);
        transactionIdx = transactionIdx + 1;

        transactions[transactionIdx].addr = _addr;
        transactions[transactionIdx].from = msg.sender;
        transactions[transactionIdx].to = _to;
        transactions[transactionIdx].amount = _amount;
		// 此时签名数量为0
        transactions[transactionIdx].signatureCount = 0;
        pendingTransactions.push(transactionIdx);
		// 交易创建事件
        emit TransactionCreated(msg.sender, _to, _amount, transactionIdx);
    }
    
	// 获取pengding队列中的交易列表
    function getPendingTransactions() public isManager view returns(uint[] memory){
        return pendingTransactions;
    }

    // 签名（入参 交易ID）
    function signTransaction(uint transactionId) public override isManager{
        Transaction storage transaction = transactions[transactionId];
        require(address(0) != transaction.from);
        require(msg.sender != transaction.from);
        require(transaction.signatures[msg.sender]!=1);
        transaction.signatures[msg.sender] = 1;
        transaction.signatureCount++;
        
		// 如果符合条件就放行
        if(transaction.signatureCount >= MIN_SIGNATURES){
            // require(address(this).balance >= transaction.amount);
            require(transaction.addr.balanceOf(address(this)) >= transaction.amount);
			// 放行 转账 执行交易
            // payable(transaction.to).transfer(transaction.amount);
            transaction.addr.transfer(transaction.to,transaction.amount);


			// 触发转账成功事件
            emit TransferFunds(transaction.to, transaction.amount);
			// 将此笔交易从pending队列中移除
            deleteTransactions(transactionId);
        }
    }
    
	// 移除交易
    function deleteTransactions(uint transacionId) internal isManager{
        uint8 replace = 0;
        for(uint i = 0; i< pendingTransactions.length; i++){
            if(1==replace){
                pendingTransactions[i-1] = pendingTransactions[i];  //后一个值替换前一个
            }else if(transacionId == pendingTransactions[i]){   //找到要移除的ID，标记1
                replace = 1;
            }
        } 
        delete pendingTransactions[pendingTransactions.length - 1];
        // pendingTransactions.length--;
        delete transactions[transacionId];
    }


  
    function GetInitializeData() public pure returns(bytes memory){
        return abi.encodeWithSignature("initialize()");
    }
}
