import {
  Clarinet,
  Tx,
  Chain,
  Account,
  types
} from 'https://deno.land/x/clarinet@v1.0.0/index.ts';
import { assertEquals } from 'https://deno.land/std@0.90.0/testing/asserts.ts';

Clarinet.test({
    name: "Prevents invalid transfer parameters",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        const wallet1 = accounts.get('wallet_1')!;
        
        // Create asset
        let setup = chain.mineBlock([
            Tx.contractCall('pixieflow', 'create-asset', [
                types.ascii("Test Asset"),
                types.ascii("https://test.com/asset"),
                types.uint(1000),
                types.uint(5),
                types.ascii("Test Description"),
                types.ascii("https://test.com/image.jpg"),
                types.list([])
            ], deployer.address)
        ]);
        
        // Try zero amount transfer
        let transfer1 = chain.mineBlock([
            Tx.contractCall('pixieflow', 'transfer-shares', [
                types.uint(0),
                types.principal(wallet1.address),
                types.uint(0),
                types.uint(1000)
            ], deployer.address)
        ]);
        
        transfer1.receipts[0].result.expectErr().expectUint(105);
        
        // Try zero payment
        let transfer2 = chain.mineBlock([
            Tx.contractCall('pixieflow', 'transfer-shares', [
                types.uint(0),
                types.principal(wallet1.address),
                types.uint(100),
                types.uint(0)
            ], deployer.address)
        ]);
        
        transfer2.receipts[0].result.expectErr().expectUint(106);
    }
});

// Previous tests remain unchanged...
