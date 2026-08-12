
  // Mobile menu
  const menuToggle = document.getElementById('menuToggle');
  const navLinks = document.getElementById('navLinks');
  menuToggle.addEventListener('click', () => navLinks.classList.toggle('open'));
  navLinks.querySelectorAll('a').forEach(a => a.addEventListener('click', () => navLinks.classList.remove('open')));

  // Reveal on scroll
  const observer = new IntersectionObserver((entries) => {
    entries.forEach(e => {
      if (e.isIntersecting) { e.target.classList.add('visible'); observer.unobserve(e.target); }
    });
  }, { threshold: 0.12 });
  document.querySelectorAll('.reveal').forEach(el => observer.observe(el));

  // FAQ accordion
  document.querySelectorAll('.faq-q').forEach(btn => {
    btn.addEventListener('click', () => {
      const item = btn.parentElement;
      const wasOpen = item.classList.contains('open');
      document.querySelectorAll('.faq-item.open').forEach(i => i.classList.remove('open'));
      if (!wasOpen) item.classList.add('open');
    });
  });

  // Booking form
  const form = document.getElementById('bookingForm');
  const submitBtn = document.getElementById('submitBtn');
  const spinner = document.getElementById('spinner');
  const success = document.getElementById('bookingSuccess');

  function setError(input, show) {
    input.classList.toggle('error', show);
  }
  function validate() {
    let ok = true;
    const nama = form.nama.value.trim();
    const email = form.email.value.trim();
    const layanan = form.layanan.value;
    const emailOk = /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);

    setError(form.nama, nama === '');
    setError(form.email, email === '' || !emailOk);
    setError(form.layanan, layanan === '');
    if (nama === '') ok = false;
    if (email === '' || !emailOk) ok = false;
    if (layanan === '') ok = false;
    return ok;
  }

  form.addEventListener('input', () => {
    const ok = validate();
    submitBtn.querySelector('span:first-child').textContent = ok
      ? 'Booking Sesi Demo Sekarang'
      : 'Lengkapi Formulir di Atas';
  });

  form.addEventListener('submit', (e) => {
    e.preventDefault();
    if (!validate()) return;
    submitBtn.disabled = true;
    submitBtn.querySelector('span:first-child').style.display = 'none';
    spinner.style.display = 'inline-block';

    setTimeout(() => {
      form.style.display = 'none';
      success.style.display = 'block';
      success.scrollIntoView({ behavior: 'smooth', block: 'center' });
    }, 1400);
  });
