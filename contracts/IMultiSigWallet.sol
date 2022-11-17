interface IMultiSigWallet{
    function addManager(address manager) external ;
    function removeManager(address manager) external;
    function signTransaction(uint transactionId) external;

    function managerClaim(IERC20 _addr,uint _amount) external returns(bool);
}
