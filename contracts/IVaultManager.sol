// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.15;


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

    event Deposit(address _lender,TokenType _tkType,address _NFTaddr,uint _tokenID,bool _renewable,uint _coinIndex,uint8 _minimumLeaseTime,uint8 _maximumLeaseTime,uint _price,uint8 _gameBonus);
    event Rent(uint _lendItemID,address _NFTaddr,uint _tokenID, address _renter,uint _endtime, uint8 _gameBonus,uint _rentTimes);
    event Withdraw(uint _lendItemID,address _NFTaddr,uint _tokenID, address _lender);

    event SetPlantformBonus(uint8 _plantformBonus);
    event RenewableStatus(uint _lendItemID,bool _renewable);
    event ResetDeposit(uint _lendItemID,uint8 _minimumLeaseTime,uint8 _maximumLeaseTime,uint _price,uint8 _gameBonus); 

    function setPlantformBonus(uint8 _plantformBonus) external;

    //租金单位为USDT/天.    bonus是百分比1～99之间的数字。 
    function deposit(TokenType _tkType,address _NFTaddr,uint _tokenID,bool _renewable,uint _coinIndex,uint8 _minimumLeaseTime,uint8 _maximumLeaseTime,uint _price,uint8 _gameBonus) external returns(bool);

    //是否可续租
    function renewableStatus(uint _lendItemID,bool _renewable) external returns(bool);

    //修改deposit信息    token没有被租赁时候才可以被修改
    function resetDeposit(uint _lendItemID,uint8 _minimumLeaseTime,uint8 _maximumLeaseTime,uint _price,uint8 _gameBonus) external returns(bool);

    function withdraw(uint _lendItemID) external;
    function claim(address _coinType,uint _amount) external;

    function getMyDepositsList() external returns(AllMsg[] memory);
    function addRentCoin(address _rentCoin) external returns(bool);
    function getLendItemMsg(uint _lendItemID) external view returns(AllMsg memory _AllMsg);

    function balanceOfRentingGameTokenInContract(address _NFTaddr) external view returns(uint _balance);
    function getTokenlendItemID(address _NFTaddr,uint _tokenID) external view returns(uint[] memory);


    //调用后，租赁即时生效.   
    function rent(uint _lendItemID,uint _rentTimes) external returns(bool);

    function getMyRentsList() external returns(AllMsg[] memory);

    function userclaim(IERC20 _addr,uint _amount) external returns(bool);


}
