export declare function getInputElement(): HTMLInputElement;
export declare function getClearAllButton(): HTMLElement | null;
export declare function typeInInputElement(value: string): Promise<{
    result: string;
}>;
export declare function addChip(chipValue: string): Promise<void>;
export declare function deleteChip(chipIndex: number): void;
export declare function clearAllChips(): boolean;
