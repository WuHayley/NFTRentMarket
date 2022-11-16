// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity >=0.7.0 <0.9.0;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract tool{

    struct gameBonus{
        address gameUnion;
        uint bonus;
    }

    function payDividends(address _gameCurrency,gameBonus[] memory _list) public returns(bool){
        uint l = _list.length;
        for(uint i=0 ; i<l ;i++){
            IERC20(_gameCurrency).transfer(_list[i].gameUnion,_list[i].bonus);
        }
        return true;
    }

}
