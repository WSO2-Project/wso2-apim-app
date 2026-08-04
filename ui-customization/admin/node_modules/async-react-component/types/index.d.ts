export interface AsyncState {
    Component: any;
}
declare const ReactAsyncComponent: {
    getAsyncComponent: <T>(promise: () => Promise<T>) => any;
};
export default ReactAsyncComponent;
