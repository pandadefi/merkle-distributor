// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity =0.8.17;

import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import {IMerkleDistributor} from "./interfaces/IMerkleDistributor.sol";

error AlreadyClaimed();
error InvalidProof();


interface IVestingFactory {
    function deploy_vesting_contract(address token,
    address recipient,
    uint256 amount,
    uint256 vesting_duration,
    uint256 vesting_start) external returns(address)
}

contract MerkleDistributor is IMerkleDistributor {
    using SafeERC20 for IERC20;

    address public constant token;
    bytes32 public immutable override merkleRoot;
    VestingFactory constant = IVestingFactory(0xcf61782465Ff973638143d6492B51A85986aB347);
    // This is a packed array of booleans.
    mapping(uint256 => uint256) private claimedBitMap;
    uint256 public startedAt;
    uint256 constant duration = 86400 * 30 * 6;

    constructor(address token_, bytes32 merkleRoot_) {
        token = token_;
        merkleRoot = merkleRoot_;
        startedAt = block.timestamp;
    }

    function isClaimed(uint256 index) public view override returns (bool) {
        uint256 claimedWordIndex = index / 256;
        uint256 claimedBitIndex = index % 256;
        uint256 claimedWord = claimedBitMap[claimedWordIndex];
        uint256 mask = (1 << claimedBitIndex);
        return claimedWord & mask == mask;
    }

    function _setClaimed(uint256 index) private {
        uint256 claimedWordIndex = index / 256;
        uint256 claimedBitIndex = index % 256;
        claimedBitMap[claimedWordIndex] = claimedBitMap[claimedWordIndex] | (1 << claimedBitIndex);
    }

    function claim(uint256 index, address account, uint256 amount, bytes32[] calldata merkleProof)
        public
        virtual
        override
    {
        if (isClaimed(index)) revert AlreadyClaimed();

        // Verify the merkle proof.
        bytes32 node = keccak256(abi.encodePacked(index, account, amount));
        if (!MerkleProof.verify(merkleProof, merkleRoot, node)) revert InvalidProof();

        // Mark it claimed and send the token.
        _setClaimed(index);
        if (startedAt + duration > block.timestamp){
            IERC20(token).safeTransfer(account, amount);
        emit Claimed(index, account, amount);
        } else {
            IERC20(token).safeApprove(address(VestingFactory), amount);
            address vestingContract = VestingFactory.deploy_vesting_contract(token, account, amount, duration, startedAt);
            emit VestingCreated(index, account, amount, vestingContract)
        }
    }
}
