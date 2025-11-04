import Alamofire
import Foundation
import Moya

struct RequestErrorWrapper {
    let moyaError: MoyaError

    var afError: AFError? {
        if case let .underlying(error as AFError, _) = moyaError {
            return error
        }
        return nil
    }

    var nsError: NSError? {
        if case let .underlying(error as NSError, _) = moyaError {
            return error
        } else if let afError {
            return afError.underlyingError as? NSError
        }
        return nil
    }

    var isRequestCancelled: Bool {
        if case .explicitlyCancelled = self.afError {
            return true
        }
        return false
    }

    var defaultErrorMessage: String? {
        if self.nsError?.code == NSURLErrorTimedOut {
            "Failed to load data. Please try again later."
        } else if self.nsError?.code == NSURLErrorNotConnectedToInternet {
            "No internet connection. Check your network settings."
        } else {
            "Failed to load data. Please try again later."
        }
    }
}

protocol RequestErrorHandlable {
    var errorHandlingType: RequestErrorHandlingPlugin.RequestErrorHandlingType { get }
}

extension RequestErrorHandlable {
    var errorHandlingType: RequestErrorHandlingPlugin.RequestErrorHandlingType {
        .all
    }
}

class RequestErrorHandlingPlugin {
    enum RequestErrorHandlingType {
        enum FilterResult {
            case handledByPlugin(message: String?)
            case shouldNotHandledByPlugin
        }

        case connectionError // Includes timeouts and offline errors.
        case all
        case allWithFilter(filter: (RequestErrorWrapper) -> FilterResult)

        func handleError(_ error: RequestErrorWrapper, handler: (_ shouldHandle: Bool, _ message: String?) -> Void) {
            switch self {
            case .connectionError:
                if error.nsError?.code == NSURLErrorTimedOut {
                    handler(true, error.defaultErrorMessage)
                } else if error.nsError?.code == NSURLErrorNotConnectedToInternet {
                    handler(true, error.defaultErrorMessage)
                }
            case .all:
                handler(true, error.defaultErrorMessage)
            case let .allWithFilter(filter):
                switch filter(error) {
                case let .handledByPlugin(messsage):
                    handler(true, messsage ?? error.defaultErrorMessage)
                case .shouldNotHandledByPlugin:
                    handler(false, nil)
                }
            }
            handler(false, nil)
        }
    }
}

extension RequestErrorHandlingPlugin: PluginType {
    func prepare(_ request: URLRequest, target: TargetType) -> URLRequest {
        var request = request
        request.timeoutInterval = 30
        return request
    }

    func didReceive(_ result: Result<Response, MoyaError>, target: TargetType) {
        let requestErrorHandleSubject: RequestErrorHandlable? =
            ((target as? MultiTarget)?.target as? RequestErrorHandlable)
                ?? (target as? RequestErrorHandlable)

        guard let requestErrorHandleSubject, case let .failure(moyaError) = result else { return }

        let errorWrapper = RequestErrorWrapper(moyaError: moyaError)
        if errorWrapper.isRequestCancelled {
            return
        }

        requestErrorHandleSubject.errorHandlingType.handleError(errorWrapper) { shouldHandle, message in
            if shouldHandle, let message, !message.isEmpty {
                // show error
            }
        }
    }
}
