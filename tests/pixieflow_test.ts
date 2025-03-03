import {
  Clarinet,
  Tx,
  Chain,
  Account,
  types
} from 'https://deno.land/x/clarinet@v1.0.0/index.ts';
import { assertEquals } from 'https://deno.land/std@0.90.0/testing/asserts.ts';

Clarinet.test({
    name: "Ensures proper asset creation with limits",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        
        // Test valid asset creation
        let result = chain.mineBlock([
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
        
        result.receipts[0].result.expectOk().expectUint(0);
        
        // Test exceeding max shares
        let invalid = chain.mineBlock([
            Tx.contractCall('pixieflow', 'create-asset', [
                types.ascii("Invalid Asset"),
                types.ascii("https://test.com/asset"),
                types.uint(2000000000), // Exceeds max
                types.uint(5),
                types.ascii("Test Description"),
                types.ascii("https://test.com/image.jpg"),
                types.list([])
            ], deployer.address)
        ]);
        
        invalid.receipts[0].result.expectErr().expectUint(101);
    }
});

[Previous tests remain unchanged...]
