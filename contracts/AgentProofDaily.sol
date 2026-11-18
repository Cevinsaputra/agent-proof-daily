// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @notice Minimal view of the SPACE ID Agent ID registry (ERC-721) on BNB Chain.
/// @dev Registry address published in Binance Wallet's Agent ID Hackathon announcement.
interface IAgentIdRegistry {
    function balanceOf(address owner) external view returns (uint256);
}

/// @title AgentProofDaily
/// @notice A daily check-in for Binance Agent ID holders. One check-in per
///         Agent ID wallet per UTC day builds a streak. The first check-in
///         mints a soulbound (non-transferable) badge whose on-chain metadata
///         always shows the holder's live streak.
/// @dev Design rules, on purpose:
///      - No owner, no admin keys, no pause, no fees, no payable functions.
///        Nobody can change the rules, move funds, or stop the contract.
///      - The only external call is a read of the official Agent ID registry:
///        holding an Agent ID (a `.ai` name for an Agentic Wallet) is the one
///        and only key. Agent ID is not a side feature here; it is the gate,
///        the identity, and the badge's reason to exist.
contract AgentProofDaily {
    // ------------------------------------------------------------------
    // Agent ID gate
    // ------------------------------------------------------------------

    /// @notice The official SPACE ID Agent ID registry on BNB Chain.
    IAgentIdRegistry public constant AGENT_ID =
        IAgentIdRegistry(0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F);

    // ------------------------------------------------------------------
    // Badge identity (minimal soulbound ERC-721 surface)
    // ------------------------------------------------------------------

    string public constant name = "Agent Proof Daily Badge";
    string public constant symbol = "APD";

    // ------------------------------------------------------------------
    // State
    // ------------------------------------------------------------------

    struct Proof {
        uint64 lastDay; // UTC day number of the last check-in (0 = never)
        uint64 streak; // current consecutive-day streak
        uint64 bestStreak; // longest streak ever reached
        uint32 total; // lifetime check-ins
        uint256 badgeId; // soulbound badge id (0 = not minted yet)
    }

    mapping(address => Proof) private _proofs;
    mapping(uint256 => address) private _badgeOwner;
    address[] private _users;

    uint256 private _nextBadgeId = 1;

    /// @notice Total check-ins across every Agent ID holder, all time.
    uint256 public totalCheckIns;

    // ------------------------------------------------------------------
    // Events & errors
    // ------------------------------------------------------------------

    event CheckedIn(address indexed user, uint256 day, uint256 streak, uint256 total);
    event BadgeMinted(address indexed user, uint256 indexed badgeId);

    error NoAgentId();
    error AlreadyCheckedInToday();
    error SoulboundBadge();
    error UnknownBadge();

    // ------------------------------------------------------------------
    // Core action
    // ------------------------------------------------------------------

    /// @notice Check in for today. Requires holding a Binance Agent ID.
    /// @dev One check-in per wallet per UTC day. A check-in on the day right
    ///      after the previous one extends the streak; any gap restarts it.
    function checkIn() external {
        if (AGENT_ID.balanceOf(msg.sender) == 0) revert NoAgentId();

        uint256 today = block.timestamp / 1 days;
        Proof storage p = _proofs[msg.sender];
        if (p.lastDay == today) revert AlreadyCheckedInToday();

        if (p.lastDay == today - 1) {
            p.streak += 1;
        } else {
            p.streak = 1;
        }
        if (p.streak > p.bestStreak) p.bestStreak = p.streak;
        p.lastDay = uint64(today);
        p.total += 1;
        totalCheckIns += 1;

        if (p.badgeId == 0) {
            uint256 badgeId = _nextBadgeId++;
            p.badgeId = badgeId;
            _badgeOwner[badgeId] = msg.sender;
            _users.push(msg.sender);
            emit BadgeMinted(msg.sender, badgeId);
        }

        emit CheckedIn(msg.sender, today, p.streak, p.total);
    }

    // ------------------------------------------------------------------
    // Reads
    // ------------------------------------------------------------------

    /// @notice The current UTC day number used by the contract.
    function currentDay() public view returns (uint256) {
        return block.timestamp / 1 days;
    }

    /// @notice Whether `user` has already checked in today.
    function checkedInToday(address user) external view returns (bool) {
        return _proofs[user].lastDay == currentDay() && _proofs[user].total > 0;
    }

    /// @notice Full proof record for `user`:
    ///         (lastDay, streak, bestStreak, total, badgeId).
    function proofOf(address user)
        external
        view
        returns (uint64 lastDay, uint64 streak, uint64 bestStreak, uint32 total, uint256 badgeId)
    {
        Proof storage p = _proofs[user];
        return (p.lastDay, p.streak, p.bestStreak, p.total, p.badgeId);
    }

    /// @notice How many distinct Agent ID holders have ever checked in.
    function uniqueUsers() external view returns (uint256) {
        return _users.length;
    }

    /// @notice The user address at leaderboard index `i` (join order).
    function userAt(uint256 i) external view returns (address) {
        return _users[i];
    }

    // ------------------------------------------------------------------
    // Soulbound badge: the ERC-721 surface wallets and explorers expect.
    // Transfers and approvals always revert — the badge is the identity's
    // proof of presence and can never change hands.
    // ------------------------------------------------------------------

    function balanceOf(address owner) external view returns (uint256) {
        return _proofs[owner].badgeId == 0 ? 0 : 1;
    }

    function ownerOf(uint256 badgeId) public view returns (address) {
        address owner = _badgeOwner[badgeId];
        if (owner == address(0)) revert UnknownBadge();
        return owner;
    }

    function transferFrom(address, address, uint256) external pure {
        revert SoulboundBadge();
    }

    function safeTransferFrom(address, address, uint256) external pure {
        revert SoulboundBadge();
    }

    function safeTransferFrom(address, address, uint256, bytes memory) external pure {
        revert SoulboundBadge();
    }

    function approve(address, uint256) external pure {
        revert SoulboundBadge();
    }

    function setApprovalForAll(address, bool) external pure {
        revert SoulboundBadge();
    }

    function getApproved(uint256) external pure returns (address) {
        return address(0);
    }

    function isApprovedForAll(address, address) external pure returns (bool) {
        return false;
    }

    function supportsInterface(bytes4 interfaceId) external pure returns (bool) {
        return interfaceId == 0x01ffc9a7 // ERC-165
            || interfaceId == 0x80ac58cd // ERC-721
            || interfaceId == 0x5b5e139f; // ERC-721 metadata
    }

    /// @notice Live on-chain metadata: the streak in the JSON and in the SVG
    ///         artwork is read from current state, so the badge grows with
    ///         its holder.
    function tokenURI(uint256 badgeId) external view returns (string memory) {
        address owner = ownerOf(badgeId);
        Proof storage p = _proofs[owner];

        string memory json = string.concat(
            '{"name":"Agent Proof Daily Badge #',
            _toString(badgeId),
            '","description":"Soulbound proof of daily presence for a Binance Agent ID holder. ',
            "The streak in this metadata is live on-chain state.",
            '","image":"data:image/svg+xml;base64,',
            _b64(bytes(_svg(p.streak))),
            '","attributes":[',
            '{"trait_type":"Current streak (days)","value":',
            _toString(p.streak),
            '},{"trait_type":"Best streak (days)","value":',
            _toString(p.bestStreak),
            '},{"trait_type":"Total check-ins","value":',
            _toString(p.total),
            "}]}"
        );
        return string.concat("data:application/json;base64,", _b64(bytes(json)));
    }

    function _svg(uint64 streak) internal pure returns (string memory) {
        return string.concat(
            "<svg xmlns='http://www.w3.org/2000/svg' width='400' height='400'>",
            "<rect width='400' height='400' rx='32' fill='#0b0e11'/>",
            "<text x='200' y='150' font-family='monospace' font-size='34' fill='#f0b90b' text-anchor='middle'>AGENT PROOF</text>",
            "<text x='200' y='245' font-family='monospace' font-size='110' fill='#ffffff' text-anchor='middle'>",
            _toString(streak),
            "</text>",
            "<text x='200' y='300' font-family='monospace' font-size='26' fill='#8a919c' text-anchor='middle'>DAY STREAK</text>",
            "</svg>"
        );
    }

    // ------------------------------------------------------------------
    // Small string / base64 helpers (self-contained, no imports)
    // ------------------------------------------------------------------

    function _toString(uint256 value) internal pure returns (string memory) {
        if (value == 0) return "0";
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }

    function _b64(bytes memory data) internal pure returns (string memory) {
        bytes memory table = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
        if (data.length == 0) return "";
        bytes memory result = new bytes(4 * ((data.length + 2) / 3));
        uint256 j;
        for (uint256 i = 0; i < data.length; i += 3) {
            uint256 b0 = uint8(data[i]);
            uint256 b1 = i + 1 < data.length ? uint8(data[i + 1]) : 0;
            uint256 b2 = i + 2 < data.length ? uint8(data[i + 2]) : 0;
            result[j++] = table[(b0 >> 2) & 0x3f];
            result[j++] = table[((b0 & 0x03) << 4) | (b1 >> 4)];
            result[j++] = i + 1 < data.length ? table[((b1 & 0x0f) << 2) | (b2 >> 6)] : bytes1("=");
            result[j++] = i + 2 < data.length ? table[b2 & 0x3f] : bytes1("=");
        }
        return string(result);
    }
}
