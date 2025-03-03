# TODO:
#	1. Write proper Makefile!! Especially for:
#		a. deployment onchain - DONE
#		b. easy test deployment and testing
#		c. easy use of tools (eg: Slither,SMT Checker, etc)

# ***IMPORTANT NOTE FOR DEPLOYMENT TO SEPOLIA TESTNET and MAINNET***
# After deploying the contracts, need to wait for the block to be confirmed (~15 seconds) before performing 
#	ownership transfer of the DecentralizedStableCoin contract to the DSCEngine contract.
# Specifically:
# 1. run make deploy ARGS="--testnet" or make deploy ARGS="--mainnet"
# 2. wait for the block to be confirmed
# 3. run make changeowner ARGS="--testnet" or make changeowner ARGS="--mainnet"

-include .env

.PHONY: all test clean deploy deploytestnet deployanvil fund help install snapshot format anvil changeowner

DEFAULT_ANVIL_KEY := 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

ANVIL_ARGS := --rpc-url $(DEFAULT_ANVIL_RPC_URL) --private-key $(DEFAULT_ANVIL_KEY) --broadcast

TESTNET_ARGS := --rpc-url $(SEPOLIA_ALCHEMY_RPC_URL) --account MM_TEST_WALLET --password-file $(PASSWORD_FILE) --broadcast

MAINNET_ARGS := --rpc-url $(MAINNET_ALCHEMY_RPC_URL) --account MM_TEST_WALLET --password-file $(PASSWORD_FILE) --broadcast

ifeq ($(findstring --mainnet,$(ARGS)),--mainnet)
	NETWORK_ARGS := $(MAINNET_ARGS)
else ifeq ($(findstring --testnet,$(ARGS)),--testnet)
	NETWORK_ARGS := $(TESTNET_ARGS)
else
	NETWORK_ARGS := $(ANVIL_ARGS)
endif

deploy:
	@forge script script/DeployDSC.s.sol:DeployDSC $(NETWORK_ARGS) --verify --etherscan-api-key $(ETHERSCAN_API_KEY)

changeowner:
	@forge script script/ChangeOwner.s.sol:ChangeOwner $(NETWORK_ARGS)

help:
	@echo "Usage:"
	@echo "  make deploy [ARGS=...]\n    example: make deploy ARGS=\"--network sepolia\""
	@echo ""
	@echo "  make fund [ARGS=...]\n    example: make deploy ARGS=\"--network sepolia\""

all: clean remove install update build

# Clean the repo
clean  :; forge clean

# Remove modules
remove :; rm -rf .gitmodules && rm -rf .git/modules/* && rm -rf lib && touch .gitmodules && git add . && git commit -m "modules"

install :; forge install cyfrin/foundry-devops@0.1.0 --no-commit && forge install smartcontractkit/chainlink-brownie-contracts@0.6.1 --no-commit && forge install foundry-rs/forge-std@v1.5.3 --no-commit && forge install openzeppelin/openzeppelin-contracts@v4.8.3 --no-commit

# Update Dependencies
update:; forge update

build:; forge build

test :; forge test 

coverage :; forge coverage --report debug > coverage-report.txt

snapshot :; forge snapshot

format :; forge fmt

anvil :; anvil -m 'test test test test test test test test test test test junk' --steps-tracing --block-time 1


