// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {Script} from "forge-std/Script.sol";
import {Raffle} from "../../src/raffle.sol";
import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {Vm} from "forge-std/Vm.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";

contract TestRaffle is Test {
    /* Events */

    event EnteredRaffle(address indexed player);

    Raffle raffle;
    HelperConfig helperConfig;
    uint256 entranceFee;
    uint256 interval;
    address vrfCoordinator;
    bytes32 gasLane;
    uint64 subscriptionId;
    uint32 callBackGasLimit;
    address link;

    address public PLAYER = makeAddr("player");
    uint256 public constant STARTING_USER_BALANCE = 10 ether;

    function setUp() external {
        DeployRaffle deployer = new DeployRaffle();
        (raffle, helperConfig) = deployer.run();
        (
            entranceFee,
            interval,
            vrfCoordinator,
            gasLane,
            subscriptionId,
            callBackGasLimit,
            link
        ) = helperConfig.activeNetworkConfig();
        vm.deal(PLAYER, STARTING_USER_BALANCE);
    }

    modifier funded() {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        _;
    }

    modifier timeSkip() {
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        _;
    }

    function testRaffleInitializesInOpenState() public view {
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
    }

    // ernter raffle
    function testRaffleRevertsWhenYouDontPayEnough() public {
        // Arange
        vm.prank(PLAYER);

        // Act / assert
        vm.expectRevert(Raffle.Raffle__NotEnoughEth.selector);
        raffle.enterRaffle();
    }

    function testRaffleRecordsPlayerWhenTheyEnter() public funded {
        // Arange
        //vm.prank(PLAYER);

        // Act / assert
        //raffle.enterRaffle{value: entranceFee}();
        address playerRecorded = raffle.getPlayer(0);
        assert(PLAYER == playerRecorded);
    }

    function testEminsEventOnEntrance() public {
        vm.prank(PLAYER);
        vm.expectEmit(true, false, false, false, address(raffle));
        emit EnteredRaffle(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
    }

    function testCantEnterWhileRaffleIsCalculating() public funded {
        //vm.prank(PLAYER);
        //raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        raffle.performUpkeep("");
        vm.expectRevert(Raffle.Raffle__RaffleNotOpen.selector);
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
    }

    //////////////////////////////////////////////////
    //check upkeep
    //////////////////////////////////////////////////

    function testCheckUpkeepReturnsFalseIfNoBalance() public {
        //arange
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        //Act
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");
        //assert
        assert(!upkeepNeeded);
    }

    function testCheckUpkeepReturnsFalseIfRaffleNotOpen()
        public
        funded
        timeSkip
    {
        //Arange
        //vm.prank(PLAYER);
        //raffle.enterRaffle{value: entranceFee}();
        //vm.warp(block.timestamp + interval + 1);
        //vm.roll(block.number + 1);
        raffle.performUpkeep("");
        //Act
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");

        //assert
        assert(!upkeepNeeded);
    }

    function testCheckUpkeepReturnsFalseIfEnoughTimeHasntPassed()
        public
        funded
    {
        //Arange
        //vm.prank(PLAYER);
        //raffle.enterRaffle{value: entranceFee}();
        //Act
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");
        //assert
        assert(!upkeepNeeded);
    }

    function testCheckUpkeepReturnsTrueWhenParametersAreGood()
        public
        funded
        timeSkip
    {
        //Arange
        //vm.prank(PLAYER);
        //raffle.enterRaffle{value: entranceFee}();
        //vm.warp(block.timestamp + interval + 1);
        //vm.roll(block.number + 1);
        //Act
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");

        //assert
        assert(upkeepNeeded);
    }

    //////////////////////////////////////////////////
    //perform upkeep
    //////////////////////////////////////////////////

    function testPerformUpkeepCanOnlyRunIfCheckUpkeepIsTrue()
        public
        funded
        timeSkip
    {
        //Arange
        //vm.prank(PLAYER);
        //raffle.enterRaffle{value: entranceFee}();
        //vm.warp(block.timestamp + interval + 1);
        //vm.roll(block.number + 1);
        //Act
        //if performUpkeep() doesnt revert test will pass
        raffle.performUpkeep("");
        //assert
    }

    function testPerformUpkeepRevertsIfCheckUpkeepIsFalse() public {
        //Arange
        uint256 currentBalance = 0;
        uint256 numPlayers = 0;
        uint256 raffleState = 0;
        //Act
        vm.expectRevert(
            abi.encodeWithSelector(
                Raffle.Raffle__UpkeepNotNeeded.selector,
                currentBalance,
                numPlayers,
                raffleState
            )
        );
        raffle.performUpkeep("");
        //assert
    }

    function testPerformUpkeepUpdatesRaffleStateAndEmitsRequestId()
        public
        funded
        timeSkip
    {
        //Act
        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];

        Raffle.RaffleState rState = raffle.getRaffleState();

        assert(uint256(requestId) > 0);
        assert(uint256(rState) == 1);
    }

    //////////////////////////////////////////////////
    //fulfillRandomWords
    //////////////////////////////////////////////////

    modifier skipOnChain() {
        if (block.chainid != 31337) {
            return;
        }
        _;
    }

    function testFulfillRandomWordsCanOnlyBeCalledAfterPerformUpkeep(
        uint256 randomRequestId
    ) public skipOnChain funded timeSkip {
        //Arange
        vm.expectRevert("nonexistent request");
        VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(
            randomRequestId,
            address(raffle)
        );
    }

    function testFulfillRandomWordsPicksWinnerResetsAndSendsMoney()
        public
        skipOnChain
        funded
        timeSkip
    {
        //Arange
        uint256 additionalEntrants = 5;
        uint256 startingIndex = 1;
        for (
            uint256 i = startingIndex;
            i < additionalEntrants + startingIndex;
            i++
        ) {
            address player = address(uint160(i));
            hoax(player, STARTING_USER_BALANCE);
            raffle.enterRaffle{value: entranceFee}();
        }

        uint256 prize = entranceFee * (additionalEntrants + 1);
        uint256 previousTimeStamp = raffle.getLastTimeStamp();

        vm.recordLogs();
        raffle.performUpkeep(""); //emit requestId
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];

        //pretend to be chainlink vrf to get random number & pick winner
        VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(
            uint256(requestId),
            address(raffle)
        );

        //Assert
        assert(uint256(raffle.getRaffleState()) == 0);
        assert(raffle.getRecentWinner() != address(0));
        assert(raffle.getPlayerArrayLength() == 0);
        assert(raffle.getLastTimeStamp() > previousTimeStamp);
        console.log(raffle.getRecentWinner().balance);
        console.log(prize + STARTING_USER_BALANCE - entranceFee);
        assert(
            raffle.getRecentWinner().balance ==
                prize + STARTING_USER_BALANCE - entranceFee
        );
    }
}
