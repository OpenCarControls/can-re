export interface ToolbarAction {
    id: string;
    group: string;
    label: string;
    icon?: any;
    onClick: () => void;
    order?: number;
}

class ToolbarRegistryImpl {
    private actions: ToolbarAction[] = [];

    register(action: ToolbarAction) {
        // If action already exists (e.g. HMR), replace it
        const existingIdx = this.actions.findIndex(a => a.id === action.id);
        if (existingIdx >= 0) {
            this.actions[existingIdx] = action;
        } else {
            this.actions.push(action);
        }
        window.dispatchEvent(new CustomEvent('toolbarUpdated'));
    }

    getActions() {
        return [...this.actions].sort((a, b) => {
            if (a.group !== b.group) return a.group.localeCompare(b.group);
            return (a.order || 0) - (b.order || 0);
        });
    }
}

export const ToolbarRegistry = new ToolbarRegistryImpl();
