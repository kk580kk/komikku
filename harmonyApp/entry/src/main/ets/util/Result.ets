/**
 * 统一错误与结果类型。
 * 业务层不把异常抛到 UI：domain 层捕获后转成 Result 交给页面渲染。
 */

export class AppError {
  static readonly NETWORK: string = 'network';
  static readonly PARSE: string = 'parse';
  static readonly STORAGE: string = 'storage';
  static readonly UNKNOWN: string = 'unknown';

  kind: string;
  message: string;

  constructor(kind: string, message: string) {
    this.kind = kind;
    this.message = message;
  }

  static network(message: string): AppError {
    return new AppError(AppError.NETWORK, message);
  }

  static parse(message: string): AppError {
    return new AppError(AppError.PARSE, message);
  }

  static storage(message: string): AppError {
    return new AppError(AppError.STORAGE, message);
  }

  static unknown(message: string): AppError {
    return new AppError(AppError.UNKNOWN, message);
  }
}

export class Result<T> {
  ok: boolean;
  data?: T;
  error?: AppError;

  constructor(ok: boolean, data?: T, error?: AppError) {
    this.ok = ok;
    this.data = data;
    this.error = error;
  }
}

export function ok<T>(data: T): Result<T> {
  return new Result<T>(true, data, undefined);
}

export function fail<T>(error: AppError): Result<T> {
  return new Result<T>(false, undefined, error);
}
