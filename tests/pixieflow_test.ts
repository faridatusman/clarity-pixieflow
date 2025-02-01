import {
  Clarinet,
  Tx,
  Chain,
  Account,
  types
} from 'https://deno.land/x/clarinet@v1.0.0/index.ts';
import { assertEquals } from 'https://deno.land/std@0.90.0/testing/asserts.ts';

// Previous tests remain unchanged...

Clarinet.test({
    name: "Can create asset with metadata and royalties",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        
        let block = chain.mineBlock([
            Tx.contractCall('pixieflow', 'create-asset', [
                types.ascii("Test Asset"),
                types.ascii("https://test.com/asset"),
                types.uint(1000),
                types.uint(5), // 5% royalty
                types.ascii("Test Description"),
                types.ascii("https://test.com/image.jpg"),
                types.list([
                    types.tuple({
                        trait: types.ascii("category"),
                        value: types.ascii("art")
                    })
                ])
            ], deployer.address)
        ]);
        
        block.receipts[0].result.expectOk().expectUint(0);
        
        let metadata = chain.callReadOnlyFn(
            'pixieflow',
            'get-metadata',
            [types.uint(0)],
            deployer.address
        );
        
        assertEquals(
            metadata.result.expectOk().data['description'],
            types.ascii("Test Description")
        );
    }
});

Clarinet.test({
    name: "Handles royalty payments correctly",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        const wallet1 = accounts.get('wallet_1')!;
        
        // Create asset with 5% royalty
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
        
        // Transfer with payment
        let transfer = chain.mineBlock([
            Tx.contractCall('pixieflow', 'transfer-shares', [
                types.uint(0),
                types.principal(wallet1.address),
                types.uint(500),
                types.uint(1000) // 1000 payment, should result in 50 royalty
            ], deployer.address)
        ]);
        
        transfer.receipts[0].result.expectOk().expectBool(true);
        
        let royaltyInfo = chain.callReadOnlyFn(
            'pixieflow',
            'get-royalty-info',
            [types.uint(0)],
            deployer.address
        );
        
        assertEquals(
            royaltyInfo.result.expectOk().data['total-paid'],
            types.uint(50)
        );
    }
});
