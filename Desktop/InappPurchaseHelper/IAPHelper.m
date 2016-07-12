//
//  IAPHelper.m
//  In App Rage
//
//  Created by Ray Wenderlich on 9/5/12.
//  Copyright (c) 2012 Razeware LLC. All rights reserved.
//

// 1
#import "IAPHelper.h"
#import <StoreKit/StoreKit.h>

NSString *const IAPHelperProductPurchasedNotification = @"IAPHelperProductPurchasedNotification";
NSString *const IAPHelperProductPurchasedNotificationWithoutValidate = @"IAPHelperProductPurchasedNotificationWithoutValidate";

// 2
@interface IAPHelper () <SKProductsRequestDelegate, SKPaymentTransactionObserver>
@end

// 3
@implementation IAPHelper {
    SKProductsRequest * _productsRequest;
    RequestProductsCompletionHandler _completionHandler;
    
    NSSet * _productIdentifiers;
    NSMutableSet * _purchasedProductIdentifiers;
}

- (id)initWithProductIdentifiers:(NSSet *)productIdentifiers {
    
    if ((self = [super init])) {
        // Store product identifiers
        _productIdentifiers = productIdentifiers;
        // Check for previously purchased products
        _purchasedProductIdentifiers = [NSMutableSet set];
        for (NSString * productIdentifier in _productIdentifiers) {
            BOOL productPurchased = [[NSUserDefaults standardUserDefaults] boolForKey:productIdentifier];
            if (productPurchased) {
                [_purchasedProductIdentifiers addObject:productIdentifier];
                NSLog(@"Previously purchased: %@", productIdentifier);
            } else {
                NSLog(@"Not purchased: %@", productIdentifier);
            }
        }
        // Add self as transaction observer
        [[SKPaymentQueue defaultQueue] addTransactionObserver:self];
        
    }
    return self;
    
}

- (void)requestProductsWithCompletionHandler:(RequestProductsCompletionHandler)completionHandler {
    // 1
    _completionHandler = [completionHandler copy];
    // 2
    _productsRequest = [[SKProductsRequest alloc] initWithProductIdentifiers:_productIdentifiers];
    _productsRequest.delegate = self;
    [_productsRequest start];
    
}

- (BOOL)productPurchased:(NSString *)productIdentifier {
    return [_purchasedProductIdentifiers containsObject:productIdentifier];
}

- (void)buyProduct:(SKProduct *)product {
    
    NSLog(@"Buying %@...", product.productIdentifier);
    
    SKPayment * payment = [SKPayment paymentWithProduct:product];
    [[SKPaymentQueue defaultQueue] addPayment:payment];
    
}

- (void)validateReceiptForTransaction:(SKPaymentTransaction *)transaction {
    
}


#pragma mark - SKProductsRequestDelegate

- (void)productsRequest:(SKProductsRequest *)request didReceiveResponse:(SKProductsResponse *)response {
    NSLog(@"Loaded list of products...");
    _productsRequest = nil;
    NSArray * skProducts = response.products;
    for (SKProduct * skProduct in skProducts) {
        NSLog(@"Found product: %@ %@ %0.2f",
              skProduct.productIdentifier,
              skProduct.localizedTitle,
              skProduct.price.floatValue);
    }
    _completionHandler(YES, skProducts);
    _completionHandler = nil;
}

- (void)request:(SKRequest *)request didFailWithError:(NSError *)error {
    
    NSLog(@"Failed to load list of products. [%@]",error.localizedDescription);
    _productsRequest = nil;
    
    _completionHandler(NO, nil);
    _completionHandler = nil;
    
}

#pragma mark SKPaymentTransactionOBserver

- (void)paymentQueue:(SKPaymentQueue *)queue updatedTransactions:(NSArray *)transactions
{
    
    for (SKPaymentTransaction * transaction in transactions) {
        switch (transaction.transactionState)
        {
            case SKPaymentTransactionStatePurchased:
                [self completeTransaction:transaction];
                break;
            case SKPaymentTransactionStateFailed:
                [self failedTransaction:transaction];
                break;
            case SKPaymentTransactionStateRestored:
                [self restoreTransaction:transaction];
            default:
                break;
        }
    };
}

- (void)completeTransaction:(SKPaymentTransaction *)transaction {
    NSLog(@"completeTransaction... [%@]",transaction.payment.productIdentifier);
    
    [self funSudhirValidateReceiptforTransaction:transaction Finish:^(BOOL success, NSDictionary *dictReceipt) {
        NSLog(@"%@",dictReceipt);
    }];
    
    
    
    //    [self validateReceiptForTransaction:transaction];

    
    [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:IAPHelperProductPurchasedNotificationWithoutValidate object:transaction.payment.productIdentifier userInfo:nil];
}

//- (void)funManualRestoreTransactionWithTransaction:(SKPaymentTransaction *)transaction Finish:(GetProductReceipttCompletionHandler)completionHandler
//{
//    
//}
-(void)funSudhirValidateReceiptforTransaction:(SKPaymentTransaction *)transaction Finish:(GetProductReceipttCompletionHandler)completionHandler
{
    NSURL *receiptURL = [[NSBundle mainBundle] appStoreReceiptURL];
    NSData *receipt = [NSData dataWithContentsOfURL:receiptURL];
    if (!receipt) {
        NSLog(@"NO VALID RECEIPT");
        
    }
    else{
        
        NSError *error;
        NSDictionary *requestContents = @{@"receipt-data": [receipt base64EncodedStringWithOptions:0],
                                          @"password":ITC_CONTENT_PROVIDER_SHARED_SECRET};
        NSData *requestData = [NSJSONSerialization dataWithJSONObject:requestContents options:0 error:&error];
        
        if (!requestData) {
            /* ... Handle error ... */
            NSLog(@"requestData ERROR : %@",error.localizedDescription);
        }
        
        NSString * strUrl = ITMS_PROD_VERIFY_RECEIPT_URL;
#ifdef DEBUG
        strUrl = ITMS_SANDBOX_VERIFY_RECEIPT_URL
#endif
        
        // Create a POST request with the receipt data.
        NSURL *storeURL = [NSURL URLWithString:strUrl];
        NSMutableURLRequest *storeRequest = [NSMutableURLRequest requestWithURL:storeURL];
        [storeRequest setHTTPMethod:@"POST"];
        [storeRequest setHTTPBody:requestData];
        
        // Make a connection to the iTunes Store on a background queue.
        NSOperationQueue *queue = [[NSOperationQueue alloc] init];
        [NSURLConnection sendAsynchronousRequest:storeRequest queue:queue
                               completionHandler:^(NSURLResponse *response, NSData *data, NSError *connectionError) {
                                   
                                   if (connectionError) {
                                       /* ... Handle error ... */
                                       NSLog(@"ERROR IN VALIDATE RECEIPT %@",connectionError.description);
                                        completionHandler(connectionError, nil);
                                   } else {
                                       NSError *error;
                                       NSDictionary *jsonResponse = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
                                       
                                       completionHandler(error, jsonResponse);
                                       
                                       if (!jsonResponse) {
                                           /* ... Handle error ...*/
                                           NSLog(@"VALID RECEIPT NOT FOUND RESPONSE %@",error.localizedDescription);
                                       }
                                       else
                                       {
                                           NSString * strStatus = [NSString stringWithFormat:@"%@",[jsonResponse objectForKey:@"status"]];
                                           if ([strStatus isEqualToString:@"0"])
                                           {
                                               /* ... Success full Get Receipt Validation ...*/
                                               for (NSDictionary * dictPurchasedProduct in [jsonResponse objectForKey:@"latest_receipt_info"])
                                               {
                                                   NSLog(@"RECEIPT PURCHASE DATE : [%@] EXP DATE : [%@]",[dictPurchasedProduct objectForKey:@"purchase_date"],[dictPurchasedProduct objectForKey:@"expires_date"]);
                                               }
                                           }
                                           else
                                           {
                                               /* ... Handle error Receipt Validation ...*/
                                               NSLog(@"RECEIPT VALIDATION ERROR CODE [%@]",strStatus);
                                           }
                                           
                                       }
                                       /* ... Send a response back to the device ... */
                                   }
                                  
                               }];
    }
}

- (void)restoreTransaction:(SKPaymentTransaction *)transaction {
    NSLog(@"restoreTransaction... %@",transaction.payment.productIdentifier);
    
//     [self funSudhirValidateReceiptforTransaction:transaction];
//    [self validateReceiptForTransaction:transaction];
    [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
}

- (void)failedTransaction:(SKPaymentTransaction *)transaction {
    
    NSLog(@"failedTransaction...");
    if (transaction.error.code != SKErrorPaymentCancelled)
    {
        NSLog(@"Transaction error: %@", transaction.error.localizedDescription);
    }
    
    [[SKPaymentQueue defaultQueue] finishTransaction: transaction];
}

- (void)provideContentForProductIdentifier:(NSString *)productIdentifier {
    
    if ([productIdentifier isEqualToString:@"com.razeware.inapprage.randomrageface"]) {
        int currentValue = [[NSUserDefaults standardUserDefaults] integerForKey:@"com.razeware.inapprage.randomrageface"];
        currentValue += 5;
        [[NSUserDefaults standardUserDefaults] setInteger:currentValue forKey:@"com.razeware.inapprage.randomrageface"];
        [[NSUserDefaults standardUserDefaults] synchronize];
    } else {
        [_purchasedProductIdentifiers addObject:productIdentifier];
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:productIdentifier];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
    [[NSNotificationCenter defaultCenter] postNotificationName:IAPHelperProductPurchasedNotification object:productIdentifier userInfo:nil];
}

- (void)restoreCompletedTransactions {
    NSLog(@"Start Restoring Transactions!!");
    [[SKPaymentQueue defaultQueue] restoreCompletedTransactions];
}

@end