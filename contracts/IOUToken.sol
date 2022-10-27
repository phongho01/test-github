// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract IOUToken is ERC20 {

	constructor(address reBakedDao_, uint256 totalSupply_)
		ERC20("IOU Token", "IOUT")
	{
		_mint(reBakedDao_, totalSupply_);
	}

	function burn(uint256 amount_)
		external
	{
		_burn(msg.sender, amount_);
	}

}