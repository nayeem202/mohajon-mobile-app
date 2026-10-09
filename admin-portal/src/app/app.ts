import { CommonModule } from '@angular/common';
import { Component, OnInit, computed, signal } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { PaymentRow, PortalApiService } from './core/portal-api.service';

type View = 'overview' | 'payments' | 'support' | 'notifications';

interface PageState<T> {
  items: T[];
  page: number;
  hasMore: boolean;
}

@Component({
  selector: 'app-root',
  imports: [CommonModule, FormsModule],
  styleUrl: './app.scss',
  templateUrl: './app.html',
})
export class App implements OnInit {
  readonly activeView = signal<View>('overview');
  readonly loading = signal(false);
  readonly error = signal('');
  readonly notice = signal('');
  readonly overview = signal<Record<string, number> | null>(null);
  readonly payments = signal<PageState<PaymentRow>>({ items: [], page: -1, hasMore: false });
  readonly tickets = signal<PageState<any>>({ items: [], page: -1, hasMore: false });
  readonly selectedTicket = signal<any | null>(null);
  readonly messages = signal<PageState<any>>({ items: [], page: -1, hasMore: false });
  readonly isSignedIn = computed(() => !!this.api.token());

  email = '';
  password = '';
  reply = '';
  pushAudience: 'ALL' | 'USER' = 'ALL';
  recipientEmail = '';
  pushTitle = '';
  pushBody = '';
  pushTitleBn = '';
  pushBodyBn = '';
  notificationImage: File | null = null;
  notificationImagePreview = '';

  constructor(readonly api: PortalApiService) {}

  ngOnInit(): void {
    if (this.isSignedIn()) void this.restoreSession();
  }

  async signIn(): Promise<void> {
    await this.run(async () => {
      await this.api.login(this.email.trim(), this.password);
      this.password = '';
      await this.loadInitialData();
    });
  }

  signOut(): void {
    this.api.logout();
    this.overview.set(null);
    this.payments.set({ items: [], page: -1, hasMore: false });
    this.tickets.set({ items: [], page: -1, hasMore: false });
    this.selectedTicket.set(null);
    this.messages.set({ items: [], page: -1, hasMore: false });
    this.notice.set('');
  }

  async changeView(view: View): Promise<void> {
    this.activeView.set(view);
    await this.refreshActiveView();
  }

  async refreshActiveView(): Promise<void> {
    await this.run(async () => {
      if (this.activeView() === 'overview') await this.fetchOverview();
      if (this.activeView() === 'payments') await this.fetchPayments(0, false);
      if (this.activeView() === 'support') await this.fetchTickets(0, false);
    });
  }

  async loadMorePayments(): Promise<void> {
    const state = this.payments();
    if (!state.hasMore) return;
    await this.run(() => this.fetchPayments(state.page + 1, true));
  }

  async loadMoreTickets(): Promise<void> {
    const state = this.tickets();
    if (!state.hasMore) return;
    await this.run(() => this.fetchTickets(state.page + 1, true));
  }

  async loadOlderMessages(): Promise<void> {
    const ticket = this.selectedTicket();
    const state = this.messages();
    if (!ticket || !state.hasMore) return;
    await this.run(() => this.fetchMessages(ticket.ticketId, state.page + 1, true));
  }

  async reconcile(payment: PaymentRow): Promise<void> {
    if (
      !confirm(
        `Reconcile ${payment.paymentId}? Mohajon will verify with bKash and never manually approve a payment.`,
      )
    )
      return;
    await this.run(async () => {
      await this.api.post(`/api/v1/platform-admin/payments/${payment.paymentId}/reconcile`);
      await this.fetchPayments(0, false);
      await this.fetchOverview();
      this.notice.set('Payment reconciliation finished. The gateway result has been saved.');
    });
  }

  async openTicket(ticket: any): Promise<void> {
    await this.run(async () => {
      this.selectedTicket.set(ticket);
      this.reply = '';
      await this.fetchMessages(ticket.ticketId, 0, false);
    });
  }

  async sendReply(): Promise<void> {
    const ticket = this.selectedTicket();
    const message = this.reply.trim();
    if (!ticket || !message) return;
    await this.run(async () => {
      await this.api.post(`/api/v1/support/admin/tickets/${ticket.ticketId}/messages`, { message });
      this.reply = '';
      await this.fetchMessages(ticket.ticketId, 0, false);
      await this.fetchTickets(0, false);
      this.notice.set('Reply sent. The shop owner will receive a notification.');
    });
  }

  async sendPush(): Promise<void> {
    if (!this.pushTitle.trim() || (!this.pushBody.trim() && !this.notificationImage)) return;
    if (this.pushAudience === 'USER' && !this.recipientEmail.trim()) return;
    const target = this.pushAudience === 'ALL' ? 'all app users' : this.recipientEmail.trim();
    if (!confirm(`Send this notification to ${target}?`)) return;
    await this.run(async () => {
      const imageUrl = this.notificationImage
        ? (await this.api.uploadImage(this.notificationImage)).url
        : null;
      const result = await this.api.post('/api/v1/platform-admin/notifications/send', {
        audience: this.pushAudience,
        recipientEmail: this.pushAudience === 'USER' ? this.recipientEmail.trim() : null,
        title: this.pushTitle.trim(),
        body: this.pushBody.trim(),
        titleBn: this.pushTitleBn.trim(),
        bodyBn: this.pushBodyBn.trim(),
        imageUrl,
      });
      this.pushTitle = '';
      this.pushBody = '';
      this.pushTitleBn = '';
      this.pushBodyBn = '';
      this.clearNotificationImage();
      this.notice.set(
        `Saved to in-app inbox. Push: ${result.sent ?? 0} delivered, ${result.failed ?? 0} failed.`,
      );
    });
  }

  selectNotificationImage(event: Event): void {
    const file = (event.target as HTMLInputElement).files?.item(0) ?? null;
    if (!file) return;
    if (!file.type.startsWith('image/')) {
      this.error.set('Please select a JPG, PNG, WEBP, or GIF image.');
      return;
    }
    if (file.size > 5 * 1024 * 1024) {
      this.error.set('Image must be 5 MB or smaller.');
      return;
    }
    this.notificationImage = file;
    this.notificationImagePreview = URL.createObjectURL(file);
  }

  clearNotificationImage(): void {
    if (this.notificationImagePreview) URL.revokeObjectURL(this.notificationImagePreview);
    this.notificationImage = null;
    this.notificationImagePreview = '';
  }

  date(value: string): string {
    return value ? new Date(value).toLocaleString() : '—';
  }

  statusClass(status: string): string {
    return ['SUCCESS', 'ACTIVE', 'WAITING_FOR_OWNER'].includes(status)
      ? 'good'
      : ['PENDING', 'OPEN'].includes(status)
        ? 'pending'
        : 'bad';
  }

  private async restoreSession(): Promise<void> {
    await this.run(async () => {
      const access = await this.api.get('/api/v1/platform-admin/access');
      if (access.platformAdmin !== true)
        throw new Error('Your portal session is no longer authorized.');
      await this.loadInitialData();
    }, true);
  }

  private async loadInitialData(): Promise<void> {
    await Promise.all([
      this.fetchOverview(),
      this.fetchPayments(0, false),
      this.fetchTickets(0, false),
    ]);
  }

  private async fetchOverview(): Promise<void> {
    this.overview.set(await this.api.get('/api/v1/platform-admin/overview'));
  }

  private async fetchPayments(page: number, append: boolean): Promise<void> {
    const data = await this.api.get(`/api/v1/platform-admin/payments?page=${page}&size=25`);
    const current = this.payments();
    this.payments.set({
      items: append ? [...current.items, ...(data.items ?? [])] : (data.items ?? []),
      page: data.page ?? page,
      hasMore: !!data.hasMore,
    });
  }

  private async fetchTickets(page: number, append: boolean): Promise<void> {
    const data = await this.api.get(`/api/v1/support/admin/tickets?page=${page}&size=25`);
    const current = this.tickets();
    this.tickets.set({
      items: append ? [...current.items, ...(data.items ?? [])] : (data.items ?? []),
      page,
      hasMore: !!data.hasMore,
    });
  }

  private async fetchMessages(ticketId: string, page: number, append: boolean): Promise<void> {
    const data = await this.api.get(
      `/api/v1/support/tickets/${ticketId}/messages?page=${page}&size=25`,
    );
    const current = this.messages();
    const received = (data.items ?? []).reverse();
    this.selectedTicket.set(data.ticket);
    this.messages.set({
      items: append ? [...received, ...current.items] : received,
      page,
      hasMore: !!data.hasMore,
    });
  }

  private async run(work: () => Promise<void>, signOutOnError = false): Promise<void> {
    this.error.set('');
    this.notice.set('');
    this.loading.set(true);
    try {
      await work();
    } catch (error) {
      this.error.set(error instanceof Error ? error.message : 'Something went wrong.');
      if (signOutOnError) this.signOut();
    } finally {
      this.loading.set(false);
    }
  }
}
