// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/BilletChain.sol";

contract MockPriceFeed {
    int256 private _answer;
    uint256 private _updatedAt;
    uint8 private _dec;

    constructor(int256 answer, uint8 dec) {
        _answer = answer;
        _dec = dec;
        _updatedAt = block.timestamp;
    }

    function setAnswer(int256 a) external { _answer = a; }
    function setUpdatedAt(uint256 t) external { _updatedAt = t; }

    function latestRoundData() external view returns (uint80, int256, uint256, uint256, uint80) {
        return (0, _answer, 0, _updatedAt, 0);
    }

    function decimals() external view returns (uint8) { return _dec; }
}

contract BilletChainTest is Test {
    BilletChain bc;
    MockPriceFeed feed;

    address orga  = address(1);
    address alice = address(2);
    address bob   = address(3);

    uint256 prix;

    function setUp() public {
        feed = new MockPriceFeed(2000e8, 8);
        vm.prank(orga);
        bc = new BilletChain(3, 50, address(feed));
        prix = bc.ticketPriceInWei();
        vm.deal(alice, 10 ether);
        vm.deal(bob, 10 ether);
    }

    function test_achat_ok() public {
        vm.prank(alice);
        bc.buyTicket{value: prix}();
        assertEq(bc.ownerOf(0), alice);
    }

    function test_achat_mauvais_montant() public {
        vm.prank(alice);
        vm.expectRevert();
        bc.buyTicket{value: prix - 1}();
    }

    function test_achat_complet() public {
        for (uint256 i = 0; i < 3; i++) {
            address a = address(uint160(10 + i));
            vm.deal(a, 1 ether);
            vm.prank(a);
            bc.buyTicket{value: prix}();
        }
        vm.prank(alice);
        vm.expectRevert(BilletChain.SoldOut.selector);
        bc.buyTicket{value: prix}();
    }

    function test_trop_percu_achat() public {
        uint256 avant = alice.balance;
        vm.prank(alice);
        bc.buyTicket{value: prix + 0.01 ether}();
        assertEq(alice.balance, avant - prix);
    }

    function test_trop_percu_revente() public {
        vm.prank(alice);
        bc.buyTicket{value: prix}();
        uint256 prixRevente = (prix * 105) / 100;
        vm.prank(alice);
        bc.listForResale(0, prixRevente);

        uint256 avant = bob.balance;
        vm.prank(bob);
        bc.buyResaleTicket{value: prixRevente + 0.01 ether}(0);
        assertEq(bob.balance, avant - prixRevente);
    }

    function test_oracle_perime() public {
        vm.warp(block.timestamp + 2 hours);
        vm.prank(alice);
        vm.expectRevert(BilletChain.StaleOracle.selector);
        bc.buyTicket{value: prix}();
    }

    function test_oracle_prix_invalide() public {
        feed.setAnswer(-1);
        vm.prank(alice);
        vm.expectRevert(BilletChain.BadOraclePrice.selector);
        bc.buyTicket{value: prix}();
    }

    function test_revente_ok() public {
        vm.prank(alice);
        bc.buyTicket{value: prix}();

        uint256 prixRevente = (prix * 105) / 100;
        vm.prank(alice);
        bc.listForResale(0, prixRevente);

        vm.prank(bob);
        bc.buyResaleTicket{value: prixRevente}(0);

        assertEq(bc.ownerOf(0), bob);
        assertEq(bc.pendingWithdrawals(alice), prixRevente);
    }

    function test_revente_prix_trop_haut() public {
        vm.prank(alice);
        bc.buyTicket{value: prix}();

        uint256 plafond = (prix * 110) / 100;
        vm.prank(alice);
        vm.expectRevert();
        bc.listForResale(0, plafond + 1);
    }

    function test_revente_pas_proprietaire() public {
        vm.prank(alice);
        bc.buyTicket{value: prix}();

        vm.prank(bob);
        vm.expectRevert(BilletChain.NotTicketOwner.selector);
        bc.listForResale(0, prix);
    }

    function test_achat_billet_pas_en_vente() public {
        vm.prank(alice);
        bc.buyTicket{value: prix}();

        vm.prank(bob);
        vm.expectRevert(BilletChain.NotListed.selector);
        bc.buyResaleTicket{value: prix}(0);
    }

    function test_retrait_orga() public {
        vm.prank(alice);
        bc.buyTicket{value: prix}();

        uint256 avant = orga.balance;
        vm.prank(orga);
        bc.withdraw();
        assertEq(orga.balance, avant + prix);
    }

    function test_retrait_rien() public {
        vm.prank(alice);
        vm.expectRevert(BilletChain.NothingToWithdraw.selector);
        bc.withdraw();
    }

    function test_frais_plateforme() public {
        vm.prank(alice);
        bc.buyTicket{value: prix}();
        uint256 prixRevente = (prix * 105) / 100;
        vm.prank(alice);
        bc.listForResale(0, prixRevente);

        vm.prank(orga);
        bc.withdraw();

        vm.prank(bob);
        bc.buyResaleTicket{value: prixRevente}(0);

        uint256 fee = (prixRevente * 500) / 10_000;
        assertEq(bc.pendingWithdrawals(alice), prixRevente - fee);
        assertEq(bc.pendingWithdrawals(orga), fee);
    }

    function test_count_listed() public {
        vm.prank(alice);
        bc.buyTicket{value: prix}();
        vm.prank(alice);
        bc.listForResale(0, prix);

        uint256[] memory ids = new uint256[](1);
        ids[0] = 0;
        assertEq(bc.countListed(ids), 1);
    }
}
