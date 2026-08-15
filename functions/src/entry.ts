// Keep the established Functions module intact while allowing narrowly scoped
// security/compliance callables to live in dedicated source files.
export * from './index';
export {recordAdultPolicyAcceptance} from './compliance';
