// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AgentProofDaily} from "../contracts/AgentProofDaily.sol";

// Minimal cheatcode surface (avoids a forge-std dependency).
interface Vm {
    function warp(uint256 newTimestamp) external;
    function prank(address msgSender) external;
    function expectRevert(bytes4 revertData) external;
    function createSelectFork(string calldata urlOrAlias) external returns (uint256);
}

contract AgentProofDailyTest {
    Vm internal constant vm = Vm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    // Real Agent ID holder: Cevin's Agentic Wallet (plinsid.ai), verified
    // against the live SPACE ID registry on the BSC fork.
    address internal constant HOLDER = 0xe262773c49F410C009DDEe6faB019817C452dde9;
    address internal constant STRANGER = address(0xBEEF);

    AgentProofDaily internal apd;

    function setUp() public {
        vm.createSelectFork("https://bsc.publicnode.com");
        apd = new AgentProofDaily();
    }

    function _eq(uint256 a, uint256 b, string memory what) internal pure {
        require(a == b, what);
    }

    function _eqAddr(address a, address b, string memory what) internal pure {
        require(a == b, what);
    }

    function testNonHolderCannotCheckIn() public {
        vm.prank(STRANGER);
        vm.expectRevert(AgentProofDaily.NoAgentId.selector);
        apd.checkIn();
    }

    function testHolderCheckInMintsBadgeAndStartsStreak() public {
        vm.prank(HOLDER);
        apd.checkIn();

        (uint64 lastDay, uint64 streak, uint64 bestStreak, uint32 total, uint256 badgeId) = apd.proofOf(HOLDER);
        _eq(lastDay, apd.currentDay(), "lastDay");
        _eq(streak, 1, "streak");
        _eq(bestStreak, 1, "bestStreak");
        _eq(total, 1, "total");
        _eq(badgeId, 1, "badgeId");
        _eq(apd.balanceOf(HOLDER), 1, "badge balance");
        _eqAddr(apd.ownerOf(1), HOLDER, "badge owner");
        _eq(apd.uniqueUsers(), 1, "uniqueUsers");
        _eq(apd.totalCheckIns(), 1, "totalCheckIns");
        require(apd.checkedInToday(HOLDER), "checkedInToday");
    }

    function testSecondCheckInSameDayReverts() public {
        vm.prank(HOLDER);
        apd.checkIn();
        vm.prank(HOLDER);
        vm.expectRevert(AgentProofDaily.AlreadyCheckedInToday.selector);
        apd.checkIn();
    }

    function testStreakExtendsNextDayAndResetsAfterGap() public {
        vm.prank(HOLDER);
        apd.checkIn();

        vm.warp(block.timestamp + 1 days);
        vm.prank(HOLDER);
        apd.checkIn();
        (, uint64 streak,, uint32 total,) = apd.proofOf(HOLDER);
        _eq(streak, 2, "streak day2");
        _eq(total, 2, "total day2");

        // Skip a full day: the streak must restart, best streak must remain.
        vm.warp(block.timestamp + 2 days);
        vm.prank(HOLDER);
        apd.checkIn();
        (, uint64 streak2, uint64 best2, uint32 total2,) = apd.proofOf(HOLDER);
        _eq(streak2, 1, "streak after gap");
        _eq(best2, 2, "best after gap");
        _eq(total2, 3, "total after gap");
    }

    function testBadgeIsSoulbound() public {
        vm.prank(HOLDER);
        apd.checkIn();

        vm.prank(HOLDER);
        vm.expectRevert(AgentProofDaily.SoulboundBadge.selector);
        apd.transferFrom(HOLDER, STRANGER, 1);

        vm.prank(HOLDER);
        vm.expectRevert(AgentProofDaily.SoulboundBadge.selector);
        apd.approve(STRANGER, 1);
    }

    function testTokenUriIsLiveDataUri() public {
        vm.prank(HOLDER);
        apd.checkIn();
        string memory uri = apd.tokenURI(1);
        bytes memory b = bytes(uri);
        bytes memory prefix = bytes("data:application/json;base64,");
        require(b.length > prefix.length, "uri too short");
        for (uint256 i = 0; i < prefix.length; i++) {
            require(b[i] == prefix[i], "uri prefix");
        }
    }
}
