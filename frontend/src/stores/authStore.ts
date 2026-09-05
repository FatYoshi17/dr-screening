import { create } from 'zustand';
import type { UserProfile, UserRole } from '../types';

interface AuthState {
  user: UserProfile | null;
  isAuthenticated: boolean;
  login: (role: UserRole, workerId?: string) => void;
  logout: () => void;
}

const DEFAULT_HEALTH_WORKER: UserProfile = {
  id: 'HW-7401',
  name: 'Suman ASHA',
  role: 'HEALTH_WORKER',
  centreName: 'Rampur Primary Health Centre',
  district: 'Sitapur, Uttar Pradesh',
  phone: '9876001122'
};

const DEFAULT_SPECIALIST: UserProfile = {
  id: 'DR-ARVIND-01',
  name: 'Dr. Arvind Rao',
  role: 'SPECIALIST',
  centreName: 'District Hospital Ophthalmology Ward',
  district: 'Sitapur District Hospital',
  phone: '9845003344'
};

export const useAuthStore = create<AuthState>((set) => ({
  user: DEFAULT_HEALTH_WORKER, // Logged in by default for smooth evaluation, with instant switcher
  isAuthenticated: true,
  login: (role: UserRole) => {
    if (role === 'SPECIALIST') {
      set({ user: DEFAULT_SPECIALIST, isAuthenticated: true });
    } else {
      set({ user: DEFAULT_HEALTH_WORKER, isAuthenticated: true });
    }
  },
  logout: () => {
    set({ user: null, isAuthenticated: false });
  }
}));
