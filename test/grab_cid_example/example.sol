import "solady/utils/LibString.sol";

function _calculatePayment() returns (uint256 calculatePayment) {
    string[] memory cmds = new string[](9);

    // Build ffi command string
    cmds[0] = "npm";
    cmds[1] = "--silent";
    cmds[2] = "--prefix";
    cmds[3] = "utils/scripts/";
    cmds[4] = "run";
    cmds[5] = "estimateHLGas";
    cmds[6] = LibString.toHexString(originDomain);
    cmds[7] = LibString.toHexString(destinationDomain);
    cmds[8] = LibString.toString(handleGas);

    bytes memory result = vm.ffi(cmds);
    calculatePayment = abi.decode(result, (uint256));
}
