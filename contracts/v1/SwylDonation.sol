/*
    @dev: Logan (Nam) Nguyen
    @Course: SUNY Oswego - CSC 495 - Capstone
    @Instructor: Professor Bastian Tenbergen
    @Version: 1.0
    @Honor: OpenZeppelin
*/

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

//  ==========  External imports    ==========
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlEnumerableUpgradeable.sol";

import "@thirdweb-dev/contracts/openzeppelin-presets/metatx/ERC2771ContextUpgradeable.sol";
import "@thirdweb-dev/contracts/lib/CurrencyTransferLib.sol";
import "@thirdweb-dev/contracts/lib/FeeType.sol";


//  ==========  Internal imports    ==========
import { ISwylDonation } from "../../interfaces/v1/ISwylDonation.sol";

contract SwylDonation is 
    Initializable,
    ISwylDonation, 
    ERC2771ContextUpgradeable,
    ReentrancyGuardUpgradeable,
    AccessControlEnumerableUpgradeable
{
    /*///////////////////////////////////////////////////////////////
                            State variables
    //////////////////////////////////////////////////////////////*/

    /// @notice module level info
    bytes32 private constant MODULE_TYPE = bytes32("Swyl-Donation");
    uint256 private constant VERSION = 1;

    /// @dev Contract level metadata.
    string public contractURI;

    /// @dev Only lister role holders can create listings, when listings are restricted by lister address.
    bytes32 private constant DONATOR_ROLE = keccak256("DONATOR_ROLE");

    /// @dev The address of the native token wrapper contract i.e. 0xeee.
    address private immutable nativeTokenWrapper;

    /// @dev Total number of listings ever created in the marketplace.
    uint256 public totalDonationTx;


    /*///////////////////////////////////////////////////////////////
                                Mappings
    //////////////////////////////////////////////////////////////*/

    /// @dev Mapping from uid of donation => donation info. All donations have ever been made on the platform.
    mapping(uint256 => Donation) private totalDonations;


    /*///////////////////////////////////////////////////////////////
                                Modifiers
    //////////////////////////////////////////////////////////////*/
    
    /// @dev Checks whether the caller is the donation's creator
    modifier onlyDonator(uint256 _donationId) {
        require(totalDonations[_donationId].donator == _msgSender(), "!DONATOR");
        _; // move on
    }

    /// @dev Checks whether a listing exists
    modifier onlyExistingDonation(uint256 _listingId) {
        // Make sure the NFT assetContract is a valid address
        require(totalDonations[_listingId].donator != address(0), "DNE");
        _; //move on
    }


    /*///////////////////////////////////////////////////////////////
                    Constructor + initializer logic
    //////////////////////////////////////////////////////////////*/


    /** 
    * @dev This contract utilizes the @openzeppelin/upgradeable pluggin and then will be deployed behind a proxy.
    *       A proxied contract doesn't make use of a constructor and the logic in a constructor got moved into 
    *       an external initializer function.
    *
    * @notice deploying to a proxy, constructor won't be in use.
    */ 
    constructor (address _nativeTokenWrapper) initializer {
        // Initialize inherited contracts
        __ReentrancyGuard_init(); // block malicious reentrant/nested calls

        // set nativeTokenWrapper
        nativeTokenWrapper = _nativeTokenWrapper;


         // grant roles
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender()); // grant DEFAULT_ADMIN_ROLE to deployer, i.e. Swyl Service account
        _setupRole(DONATOR_ROLE, address(0)); 
    }


    /**
    * @dev This function acts like a constructor on deploying to proxy.
    *       initializer modifier is marked to make sure this function can ever be called once in this contract's lifetime
    * NOTE  from EIP7221: Secure Protocol for Native Meta Transactions (https://eips.ethereum.org/EIPS/eip-2771)
    *           - Transaction Signer - entity that signs & sends to request to Gas Relay
    *           - Gas Relay - receives a signed request off-chain from Transaction Signer and pays gas to turn it into a valid transaction that goes through Trusted Forwarder
    *           - Trusted Forwarder - a contract that is trusted by the Recipient to correctly verify the signature and nonce before forwarding the request from Transaction Signer
    *           - Recipient - a contract that can securely accept meta-transactions through a Trusted Forwarder by being compliant with this standard.
    */
    function initialize(
        address _defaultAdmin, // original deployer i.e. Swyl Service account
        string memory _contrtactURI, // contract level URI
        address[] memory _trustedForwarders
    ) external initializer {
        // Initialize inherited contracts
        __ReentrancyGuard_init(); // block malicious reentrant/nested calls
        __ERC2771Context_init(_trustedForwarders); // init trusted forwarders

        // set platform admin/contract's state info
        contractURI = _contrtactURI;

        // grant roles
        _setupRole(DEFAULT_ADMIN_ROLE, _defaultAdmin); // grant DEFAULT_ADMIN_ROLE to deployer, i.e. Swyl Service account in this case
        _setupRole(DONATOR_ROLE, address(0)); // grant LISTER_ROLE to address 0x000
    }


    /*///////////////////////////////////////////////////////////////
                        Generic contract logic
    //////////////////////////////////////////////////////////////*/
    
    /**
    * @notice receive() is a special function and only one can be defined in a smart contract.
    *       It executes on calls to the contract with no data(calldata), e.g. calls made via send() or transfer()
    *
    * @dev Lets the contract receives native tokens from `nativeTokenWrapper` withdraw
    */ 
    receive() external payable {}

    /// @dev Returns the module type of the contract
    function contractType() external pure returns (bytes32) {
        return MODULE_TYPE;
    }

    /// @dev Returns the version of the contract
    function contractVersion() external pure returns (uint8) {
        return uint8(VERSION);
    }


    /*///////////////////////////////////////////////////////////////
                Donation (create-update-delete) logic
    //////////////////////////////////////////////////////////////*/

    /**
    * @notice Lets an account make a donation and send the donation amount to a receiver.
    * 
    * @param _param MakeDonationParam - The parameter that governs the donation to be created.
    *                                   See struct MakeDonationParam for more info.
    */
    function makeDonation(MakeDonationParam memory _param) external override {}


    /**
    * @notice Only for monthly donation type.
    *
    * @notice Lets a donator make an update to the monthly donation created by them.
    *
    * @param _param UpdatedDonationParam - The parameter that governs a monthly donation to be updated.
    *                                      See struct UpdateDonationParam for more info.
    *
    */
    function updateDonation(UpdateDonationParam memory _param) external override {}


    /**
    * @notice Lets a donator cancel the monthly donation created by them.
    *
    * @param _donationId uint256 - the uid of the target donation to be deleted.
    */
    function cancelDonation(uint256 _donationId) external override {}

    /*///////////////////////////////////////////////////////////////
                            Utilities
    //////////////////////////////////////////////////////////////*/
    function _msgSender()
        internal
        view
        virtual
        override(ContextUpgradeable, ERC2771ContextUpgradeable)
        returns (address sender)
    {
        return ERC2771ContextUpgradeable._msgSender();
    }

    function _msgData()
        internal
        view
        virtual
        override(ContextUpgradeable, ERC2771ContextUpgradeable)
        returns (bytes calldata)
    {
        return ERC2771ContextUpgradeable._msgData();
    }

}