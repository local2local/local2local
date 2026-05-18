export type HBRStatus = 'ACTIVE' | 'SCHEDULED' | 'SUPERSEDED' | 'REVOKED' | 'AMENDED';

export interface HBRVersion {
  version_id: string;
  hbr_path: string;
  rule_maker: string;
  region_scope: string;
  category: string;
  version: string;
  status: HBRStatus;
  valid_from: string;
  valid_until: string | null;
  decision_recorded_at: string;
  decision_source?: string;
  decision_source_url?: string;
  supersedes_version: string | null;
  superseded_by_version: string | null;
  rules_snapshot: Record<string, any>;
  change_summary: string;
  source_commit: string;
  source_phase: string;
  provenance: 'OBSERVED' | 'CONFIRMED' | 'INFERRED' | 'GENERATED';
  confirmed_by?: string;
  created_at: string;
  amendment_history: any[];
}