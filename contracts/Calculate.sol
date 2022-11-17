// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.15;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";


library Calculate{
    using SafeMath for uint256;

    //计算租约到期时间
    function duetime(uint _rentTimes) internal view returns(uint){
        uint rentTimes = _rentTimes.mul(86400);  //按天          //计算租赁时长
        // uint rentTimes = _rentTimes.mul(60);   //按分钟
        return block.timestamp.add(rentTimes);
    }

    // //计算开始时间与当前时间的时间差
    // function timeDifference() internal view returns(uint){
    //     uint current = block.timestamp;
    //     uint start = current%86400;
    //     uint difference;
    //     if(start <= 57600){
    //         difference = 57600 - start;
    //     }else{
    //         difference = 144000 - start;
    //     }
    //     return difference;
    // }

    // function starttime() internal view returns(uint){
    //     uint difference = timeDifference();
    //     return block.timestamp.add(difference);
    // }

    // function endtime(uint _rentTimes) internal view returns(uint){
    //     uint rentTimes = _rentTimes.mul(86400);  //按天
    //     uint start = starttime();
    //     return start.add(rentTimes);
    // }


}
