// SPDX-License-Identifier: UNLICENSED

// contracts/MyNFT.sol
pragma solidity 0.8.11;

//import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "../Utils/MetachessOwnable.sol";

contract LandNFT is Context, ERC165, IERC721, IERC721Metadata, MetachessOwnable {
    using Address for address;
    using Strings for uint256;

    // Token name
    string private _name;

    // Token symbol
    string private _symbol;

    uint256 public ownerShipRange = 3600 * 24 * 30;
    address public marketAddress;

    uint256 private _tokenId=0;

    // Mapping from token ID to owner address
    mapping(uint256 => address) private _owners;

    // Mapping from token ID to owner expire Time
    mapping(uint256 => uint256) private _expireTimes;

    mapping(uint256 => address) private _borrowers;
    mapping(uint256 => uint256) private _expireBorrowTimes;

    // Mapping owner address to token count
    mapping(address => uint256) private _balances;

    // Mapping from token ID to approved address
    mapping(uint256 => address) private _tokenApprovals;

    // Mapping from owner to operator approvals
    mapping(address => mapping(address => bool)) private _operatorApprovals;

    mapping(address => bool) admins;

    modifier onlyAdmin() {
        require(admins[msg.sender], ": caller is not the admin");
        _;
    }

    modifier onlyMarketer() {
        require(msg.sender == marketAddress, ": caller is not the admin");
        _;
    }

    event SetOwnerShipRange(uint256 _timeRange);
    event SetMarketAddress(address _marketAddress);
    event LendToken(address _owner, address _borrower, uint256 _tokenId, uint256 _expireBorrowTime);

    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
    }

    function setOwnerShipRange(uint256 _timeRange) external onlyContractOwner {
        require(_timeRange > 0, "_timeRange == 0");
        ownerShipRange = _timeRange;
        emit SetOwnerShipRange(_timeRange);
    }

    function setMarketAddress(address _marketAddress) external onlyContractOwner {
        require(_marketAddress != address(0x0), "Zero address");
        marketAddress = _marketAddress;
        emit SetMarketAddress(_marketAddress);
    }

    function supportsInterface(bytes4 interfaceId) public view override(ERC165, IERC165) returns (bool) {
        return
            interfaceId == type(IERC721).interfaceId ||
            interfaceId == type(IERC721Metadata).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    function balanceOf(address owner) public view override returns (uint256) {
        return 0;
//        require(owner != address(0), "LandNFT: balance query for the zero address");
//        return _balances[owner];
    }

    function ownerOf(uint256 tokenId) public view override returns (address) {
        address owner = _owners[tokenId];
        require(owner != address(0), "ERC721: owner query for nonexistent token");
        if (_expireTimes[tokenId] < block.timestamp)
            return contractOwner();
        return owner;
    }

    function isBorrowed(uint256 tokenId) public view returns (bool) {
        if (_borrowers[tokenId] == address(0x0)) return false;
        if (_expireBorrowTimes[tokenId] < block.timestamp) return false;
        return true;
    }

    function name() public view override returns (string memory) {
        return _name;
    }

    function symbol() public view override returns (string memory) {
        return _symbol;
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");

        string memory baseURI = _baseURI();
        return bytes(baseURI).length > 0 ? string(abi.encodePacked(baseURI, tokenId.toString())) : "";
    }

    function _baseURI() internal view returns (string memory) {
        return "";
    }

    function approve(address to, uint256 tokenId) public override {
        address owner = ownerOf(tokenId);
        require(to != owner, "ERC721: approval to current owner");

        require(
            _msgSender() == owner || isApprovedForAll(owner, _msgSender()),
            "ERC721: approve caller is not owner nor approved for all"
        );

        _approve(to, tokenId);
    }

    function getApproved(uint256 tokenId) public view override returns (address) {
        require(_exists(tokenId), "ERC721: approved query for nonexistent token");

        return _tokenApprovals[tokenId];
    }

    function setApprovalForAll(address operator, bool approved) public override {
        require(operator != _msgSender(), "ERC721: approve to caller");

        _operatorApprovals[_msgSender()][operator] = approved;
        emit ApprovalForAll(_msgSender(), operator, approved);
    }

    function isApprovedForAll(address owner, address operator) public view override returns (bool) {
        if (operator == marketAddress && marketAddress != address(0x0)) return true;
        return _operatorApprovals[owner][operator];
    }

    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public override {
        //solhint-disable-next-line max-line-length
        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: transfer caller is not owner nor approved");

        _transfer(from, to, tokenId);
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public override {
        safeTransferFrom(from, to, tokenId, "");
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) public override {
        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: transfer caller is not owner nor approved");
        _safeTransfer(from, to, tokenId, _data);
    }

    function lendToken(address to, uint256 tokenId, uint256 _expireBorrowTime) external {
        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: transfer caller is not owner nor approved");
        require(_expireBorrowTime > block.timestamp && _expireBorrowTime <= _expireTimes[tokenId], "borrow time issue");
        _borrowers[tokenId] = to;
        _expireBorrowTimes[tokenId] = _expireBorrowTime;
        emit LendToken(ownerOf(tokenId), to, tokenId, _expireBorrowTime);
    }

    function borrowerOf(uint256 tokenId) public view returns (address){
        if (_expireBorrowTimes[tokenId] >= block.timestamp) return _borrowers[tokenId];
        return address(0x0);
    }

    function _safeTransfer(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) internal {
        _transfer(from, to, tokenId);
        require(_checkOnERC721Received(from, to, tokenId, _data), "ERC721: transfer to non ERC721Receiver implementer");
    }

    function _exists(uint256 tokenId) internal view returns (bool) {
        return ownerOf(tokenId) != address(0);
    }

    function _isApprovedOrOwner(address spender, uint256 tokenId) internal view returns (bool) {
        require(_exists(tokenId), "ERC721: operator query for nonexistent token");
        address owner = ownerOf(tokenId);
        return (spender == owner || getApproved(tokenId) == spender || isApprovedForAll(owner, spender));
    }

    function mint() external onlyContractOwner {
        _tokenId ++;
        _mint(contractOwner(), _tokenId);
    }

    function _safeMint(address to, uint256 tokenId) internal {
        _safeMint(to, tokenId, "");
    }

    function _safeMint(
        address to,
        uint256 tokenId,
        bytes memory _data
    ) internal {
        _mint(to, tokenId);
        require(
            _checkOnERC721Received(address(0), to, tokenId, _data),
            "ERC721: transfer to non ERC721Receiver implementer"
        );
    }

    function _mint(address to, uint256 tokenId) internal {
        require(to != address(0), "ERC721: mint to the zero address");
        require(!_exists(tokenId), "ERC721: token already minted");

        _beforeTokenTransfer(address(0), to, tokenId);

//        _balances[to] += 1;
        _owners[tokenId] = to;

        emit Transfer(address(0), to, tokenId);
    }

//    function burn(uint256 tokenId) external onlyContractOwner {
//        _burn(tokenId);
//    }

    function _burn(uint256 tokenId) internal {
        address owner = ownerOf(tokenId);
        require(owner == contractOwner() && !isBorrowed(tokenId), "can't burn token");

        _beforeTokenTransfer(owner, address(0), tokenId);

        // Clear approvals
        _approve(address(0), tokenId);

        _balances[owner] -= 1;
        delete _owners[tokenId];

        emit Transfer(owner, address(0), tokenId);
    }

    function _transfer(
        address from,
        address to,
        uint256 tokenId
    ) internal {
        require(ownerOf(tokenId) == from, "ERC721: transfer of token that is not own");
        require(!isBorrowed(tokenId), "token is borrowed");
        require(to != address(0), "ERC721: transfer to the zero address");

        address _contractOwner = contractOwner();

        address owner = ownerOf(tokenId);
        if (owner == _contractOwner) {
            require(msg.sender == _contractOwner || msg.sender == marketAddress, "only one of owner and marketer");
            _expireTimes[tokenId] = block.timestamp + ownerShipRange;
        }

        _beforeTokenTransfer(from, to, tokenId);

        // Clear approvals from the previous owner
        _approve(address(0), tokenId);
//        _balances[from] -= 1;
//        _balances[to] += 1;
        _owners[tokenId] = to;

        emit Transfer(from, to, tokenId);
    }

    function _approve(address to, uint256 tokenId) internal {
        _tokenApprovals[tokenId] = to;
        emit Approval(ownerOf(tokenId), to, tokenId);
    }

    function _checkOnERC721Received(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) private returns (bool) {
        if (to.isContract()) {
            try IERC721Receiver(to).onERC721Received(_msgSender(), from, tokenId, _data) returns (bytes4 retval) {
                return retval == IERC721Receiver(to).onERC721Received.selector;
            } catch (bytes memory reason) {
                if (reason.length == 0) {
                    revert("ERC721: transfer to non ERC721Receiver implementer");
                } else {
                    assembly {
                        revert(add(32, reason), mload(reason))
                    }
                }
            }
        } else {
            return true;
        }
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual {}
}
