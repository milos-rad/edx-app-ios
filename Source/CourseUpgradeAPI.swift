//
//  CourseUpgradeAPI.swift
//  edX
//
//  Created by Saeed Bashir on 8/17/21.
//  Copyright © 2021 edX. All rights reserved.
//

import Foundation

private let PaymentProcessor = "ios-iap"

public struct CourseUpgradeAPI {
    static let baseURL = OEXRouter.shared().environment.config.ecommerceURL ?? ""
    private static func basketDeserializer(response: HTTPURLResponse, json: JSON) -> Result<OrderBasket> {
        guard response.httpStatusCode.is2xx else {
            return Failure(e: NSError(domain: "BasketApiErrorDomain", code: response.statusCode, userInfo: [NSLocalizedDescriptionKey: json]))
        }
        return Success(v: OrderBasket(json: json))
    }
    
    static func basketAPI(with sku: String) -> NetworkRequest<OrderBasket> {
        let path = "/api/iap/v1/basket/add/?sku={sku}".oex_format(withParameters: ["sku" : sku])
        
        return NetworkRequest(
            method: .GET,
            path: path,
            requiresAuth: true,
            deserializer: .jsonResponse(basketDeserializer))
    }
    
    private static func checkoutDeserializer(response : HTTPURLResponse) -> Result<()> {
        guard response.httpStatusCode.is2xx else {
            return Failure(e: NSError(domain: "CheckoutApiErrorDomain", code: response.statusCode, userInfo: [NSLocalizedDescriptionKey: "Checkout api error"]))
        }
        return Success(v: ())
    }

    static func checkoutAPI(basketID: Int) -> NetworkRequest<()> {
        return NetworkRequest(
            method: .POST,
            path: "/api/v2/checkout/",
            requiresAuth: true,
            body: .jsonBody(JSON([
                "basket_id": basketID,
                "payment_processor": PaymentProcessor
            ])),
            deserializer: .noContent(checkoutDeserializer)
        )
    }
    
    private static func executeDeserializer(response: HTTPURLResponse, json: JSON) -> Result<OrderVerify> {
        guard response.httpStatusCode.is2xx else {
            return Failure(e: NSError(domain: "ExecuteApiErrorDomain", code: response.statusCode, userInfo: [NSLocalizedDescriptionKey: json]))
        }
        return Success(v: (OrderVerify(json: json)))
    }

    static func executeAPI(basketID: Int, productID: String, receipt: String) -> NetworkRequest<OrderVerify> {
        return NetworkRequest(
            method: .POST,
            path: "/api/iap/v1/execute/",
            requiresAuth: true,
            body: .jsonBody(JSON([
                "basket_id": basketID,
                "productId": productID,
                "purchaseToken": receipt,
                "payment_processor": PaymentProcessor
            ])),
            deserializer: .jsonResponse(executeDeserializer)
        )
    }
}

class OrderBasket: NSObject {
    let success: String
    let basketID: Int
    
    init(json: JSON) {
        success = json["success"].string ?? ""
        basketID = json["basket_id"].int ?? 0
    }
}

class OrderVerify: NSObject {
    let status: String
    let number: String
    let currency: String

    init(json: JSON) {
        status = json["status"].string ?? ""
        number = json["number"].string ?? ""
        currency = json["currency"].string ?? ""
    }
}
