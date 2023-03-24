import { ethers } from 'ethers';

const encoder = ethers.utils.defaultAbiCoder;

const calculatePayment = async () => {
  const payment = 1;

  process.stdout.write(encoder.encode(['uint256'], [payment]));
};

calculatePayment();
