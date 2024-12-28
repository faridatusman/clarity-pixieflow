import {
  Clarinet,
  Tx,
  Chain,
  Account,
  types
} from 'https://deno.land/x/clarinet@v1.0.0/index.ts';
import { assertEquals } from 'https://deno.land/std@0.90.0/testing/asserts.ts';

Clarinet.test({
    name: "Can create new fractionalized asset",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        
        let block = chain.mineBlock([
            Tx.contractCall('pixieflow', 'create-asset', [
                types.ascii("Test Asset"),
                types.ascii("https://test.com/asset"),
                types.uint(1000)
            ], deployer.address)
        ]);
        
        block.receipts[0].result.expectOk().expectUint(0);
        
        // Verify asset info
        let assetInfo = chain.callReadOnlyFn(
            'pixieflow',
            'get-asset-info',
            [types.uint(0)],
            deployer.address
        );
        
        assertEquals(assetInfo.result.expectSome().data['total-shares'], types.uint(1000));
    }
});

Clarinet.test({
    name: "Can transfer shares between users",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        const wallet1 = accounts.get('wallet_1')!;
        
        // First create asset
        let block = chain.mineBlock([
            Tx.contractCall('pixieflow', 'create-asset', [
                types.ascii("Test Asset"),
                types.ascii("https://test.com/asset"),
                types.uint(1000)
            ], deployer.address)
        ]);
        
        // Transfer shares
        let transfer = chain.mineBlock([
            Tx.contractCall('pixieflow', 'transfer-shares', [
                types.uint(0),
                types.principal(wallet1.address),
                types.uint(500)
            ], deployer.address)
        ]);
        
        transfer.receipts[0].result.expectOk().expectBool(true);
        
        // Verify balances
        let deployerShares = chain.callReadOnlyFn(
            'pixieflow',
            'get-shares',
            [types.uint(0), types.principal(deployer.address)],
            deployer.address
        );
        
        let wallet1Shares = chain.callReadOnlyFn(
            'pixieflow',
            'get-shares',
            [types.uint(0), types.principal(wallet1.address)],
            deployer.address
        );
        
        assertEquals(deployerShares.result.expectSome(), types.uint(500));
        assertEquals(wallet1Shares.result.expectSome(), types.uint(500));
    }
});

Clarinet.test({
    name: "Can add and claim revenue",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        const wallet1 = accounts.get('wallet_1')!;
        
        // Create asset and transfer shares
        let setup = chain.mineBlock([
            Tx.contractCall('pixieflow', 'create-asset', [
                types.ascii("Test Asset"),
                types.ascii("https://test.com/asset"),
                types.uint(1000)
            ], deployer.address),
            Tx.contractCall('pixieflow', 'transfer-shares', [
                types.uint(0),
                types.principal(wallet1.address),
                types.uint(500)
            ], deployer.address)
        ]);
        
        // Add revenue
        let addRevenue = chain.mineBlock([
            Tx.contractCall('pixieflow', 'add-revenue', [
                types.uint(0),
                types.uint(1000)
            ], deployer.address)
        ]);
        
        addRevenue.receipts[0].result.expectOk().expectBool(true);
        
        // Claim revenue
        let claim = chain.mineBlock([
            Tx.contractCall('pixieflow', 'claim-revenue', [
                types.uint(0)
            ], wallet1.address)
        ]);
        
        claim.receipts[0].result.expectOk().expectUint(500);
    }
});

Clarinet.test({
    name: "Can create and vote on proposals",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        const wallet1 = accounts.get('wallet_1')!;
        
        // Create asset and transfer shares
        let setup = chain.mineBlock([
            Tx.contractCall('pixieflow', 'create-asset', [
                types.ascii("Test Asset"),
                types.ascii("https://test.com/asset"),
                types.uint(1000)
            ], deployer.address),
            Tx.contractCall('pixieflow', 'transfer-shares', [
                types.uint(0),
                types.principal(wallet1.address),
                types.uint(500)
            ], deployer.address)
        ]);
        
        // Create proposal
        let createProposal = chain.mineBlock([
            Tx.contractCall('pixieflow', 'create-proposal', [
                types.uint(0),
                types.ascii("Test Proposal"),
                types.uint(100)
            ], deployer.address)
        ]);
        
        createProposal.receipts[0].result.expectOk().expectBool(true);
        
        // Vote on proposal
        let vote = chain.mineBlock([
            Tx.contractCall('pixieflow', 'vote', [
                types.uint(0),
                types.bool(true)
            ], wallet1.address)
        ]);
        
        vote.receipts[0].result.expectOk().expectBool(true);
        
        // Check vote counts
        let proposal = chain.callReadOnlyFn(
            'pixieflow',
            'get-proposal',
            [types.uint(0)],
            deployer.address
        );
        
        assertEquals(proposal.result.expectSome().data['votes-for'], types.uint(500));
    }
});