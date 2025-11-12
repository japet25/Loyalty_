pragma solidity ^0.8.24;

import { FHE, euint32, externalEuint32 } from "@fhevm/solidity/lib/FHE.sol";
import { ZamaEthereumConfig } from "@fhevm/solidity/config/ZamaConfig.sol";

contract LoyaltyZama is ZamaEthereumConfig {
    struct Member {
        address userAddress;
        euint32 encryptedPoints;
        uint32 decryptedPoints;
        uint256 lastUpdated;
        bool isVerified;
    }

    struct Business {
        address owner;
        string name;
        uint256 rewardThreshold;
        uint256 rewardAmount;
    }

    mapping(address => Member) public members;
    mapping(address => Business) public businesses;
    mapping(address => bool) public isMember;
    mapping(address => bool) public isBusiness;

    address[] public memberList;
    address[] public businessList;

    event MemberRegistered(address indexed member);
    event BusinessRegistered(address indexed business);
    event PointsUpdated(address indexed member, euint32 encryptedPoints);
    event RewardClaimed(address indexed member, address indexed business, uint256 amount);
    event DecryptionVerified(address indexed member, uint32 decryptedPoints);

    constructor() ZamaEthereumConfig() {
    }

    function registerMember(externalEuint32 encryptedPoints, bytes calldata inputProof) external {
        require(!isMember[msg.sender], "Member already registered");

        euint32 encrypted = FHE.fromExternal(encryptedPoints, inputProof);
        require(FHE.isInitialized(encrypted), "Invalid encrypted input");

        members[msg.sender] = Member({
            userAddress: msg.sender,
            encryptedPoints: encrypted,
            decryptedPoints: 0,
            lastUpdated: block.timestamp,
            isVerified: false
        });

        FHE.allowThis(members[msg.sender].encryptedPoints);
        FHE.makePubliclyDecryptable(members[msg.sender].encryptedPoints);

        isMember[msg.sender] = true;
        memberList.push(msg.sender);

        emit MemberRegistered(msg.sender);
    }

    function registerBusiness(
        string calldata name,
        uint256 rewardThreshold,
        uint256 rewardAmount
    ) external {
        require(!isBusiness[msg.sender], "Business already registered");

        businesses[msg.sender] = Business({
            owner: msg.sender,
            name: name,
            rewardThreshold: rewardThreshold,
            rewardAmount: rewardAmount
        });

        isBusiness[msg.sender] = true;
        businessList.push(msg.sender);

        emit BusinessRegistered(msg.sender);
    }

    function updatePoints(
        address member,
        externalEuint32 newEncryptedPoints,
        bytes calldata inputProof
    ) external {
        require(isMember[member], "Not a registered member");

        euint32 newPoints = FHE.fromExternal(newEncryptedPoints, inputProof);
        require(FHE.isInitialized(newPoints), "Invalid encrypted input");

        members[member].encryptedPoints = newPoints;
        members[member].lastUpdated = block.timestamp;
        members[member].isVerified = false;

        FHE.allowThis(members[member].encryptedPoints);
        FHE.makePubliclyDecryptable(members[member].encryptedPoints);

        emit PointsUpdated(member, newPoints);
    }

    function verifyDecryption(
        address member,
        bytes memory abiEncodedClearValue,
        bytes memory decryptionProof
    ) external {
        require(isMember[member], "Not a registered member");
        require(!members[member].isVerified, "Points already verified");

        bytes32[] memory cts = new bytes32[](1);
        cts[0] = FHE.toBytes32(members[member].encryptedPoints);

        FHE.checkSignatures(cts, abiEncodedClearValue, decryptionProof);

        uint32 decodedValue = abi.decode(abiEncodedClearValue, (uint32));
        members[member].decryptedPoints = decodedValue;
        members[member].isVerified = true;

        emit DecryptionVerified(member, decodedValue);
    }

    function claimReward(address business) external {
        require(isMember[msg.sender], "Not a registered member");
        require(isBusiness[business], "Not a registered business");
        require(members[msg.sender].isVerified, "Points not verified");
        require(
            members[msg.sender].decryptedPoints >= businesses[business].rewardThreshold,
            "Insufficient points"
        );

        uint256 reward = businesses[business].rewardAmount;
        
        // In a real implementation, this would transfer tokens or ETH
        // For demonstration, we'll just emit the event
        emit RewardClaimed(msg.sender, business, reward);
    }

    function getMember(address member) external view returns (
        euint32 encryptedPoints,
        uint32 decryptedPoints,
        uint256 lastUpdated,
        bool isVerified
    ) {
        require(isMember[member], "Not a registered member");
        Member storage m = members[member];
        return (m.encryptedPoints, m.decryptedPoints, m.lastUpdated, m.isVerified);
    }

    function getBusiness(address business) external view returns (
        string memory name,
        uint256 rewardThreshold,
        uint256 rewardAmount
    ) {
        require(isBusiness[business], "Not a registered business");
        Business storage b = businesses[business];
        return (b.name, b.rewardThreshold, b.rewardAmount);
    }

    function getAllMembers() external view returns (address[] memory) {
        return memberList;
    }

    function getAllBusinesses() external view returns (address[] memory) {
        return businessList;
    }

    function isAvailable() public pure returns (bool) {
        return true;
    }
}


