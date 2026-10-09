import dotenv from 'dotenv';
import express from 'express';
import cors from 'cors';
import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import mysql from 'mysql2/promise';
import { put } from '@vercel/blob';
import multer from 'multer';
import { randomBytes, randomUUID } from 'node:crypto';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const backendDirectory = dirname(fileURLToPath(import.meta.url));
dotenv.config({ path: resolve(backendDirectory, '.env') });
dotenv.config({ path: resolve(backendDirectory, '..', '.env') });

const app = express();
const port = Number(process.env.PORT || 3000);
const jwtSecret = process.env.JWT_SECRET;
if (!jwtSecret) throw new Error('JWT_SECRET must be set');

const pool = mysql.createPool({
  host: process.env.DB_HOST || '127.0.0.1',
  port: Number(process.env.DB_PORT || 3306),
  database: process.env.DB_NAME || 'btp_platform',
  user: process.env.DB_USER || 'root',
  password: process.env.DB_PASSWORD || '',
  waitForConnections: true,
  connectionLimit: 10,
  queueLimit: 0,
});

app.use(cors({ origin: process.env.CORS_ORIGIN || '*' }));
app.use(express.json({ limit: '1mb' }));
const imageUpload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 8 * 1024 * 1024, files: 1 },
});

const asyncRoute = (handler) => (req, res, next) =>
  Promise.resolve(handler(req, res, next)).catch(next);

function requireAuth(req, res, next) {
  const header = req.header('authorization') || '';
  const token = header.startsWith('Bearer ') ? header.slice(7) : null;
  if (!token) return res.status(401).json({ message: 'Authentification requise.' });
  try {
    req.user = jwt.verify(token, jwtSecret);
    return next();
  } catch {
    return res.status(401).json({ message: 'Session invalide ou expirée.' });
  }
}

function requireRole(...roles) {
  return (req, res, next) => roles.includes(req.user.role)
    ? next()
    : res.status(403).json({ message: 'Accès interdit pour ce profil.' });
}

function normalizeTelephone(value) {
  return String(value || '').replace(/[\s()-]/g, '');
}

function makeToken(user) {
  return jwt.sign({ id: user.id, role: user.role }, jwtSecret, { expiresIn: '7d' });
}

function safeUser(row) {
  return {
    id: String(row.id), fullName: row.full_name, telephone: row.telephone,
    role: row.role, city: row.city, companyName: row.company_name,
    rccm: row.rccm, trade: row.trade, experienceYears: row.experience_years,
  };
}

app.get('/api/health', asyncRoute(async (_req, res) => {
  await pool.query('SELECT 1');
  res.json({ status: 'ok', database: 'mysql' });
  console.log('Connexion a la bd: succes')
}));

app.post('/api/auth/register', asyncRoute(async (req, res) => {
  const { fullName, telephone, password, role, city, companyName, rccm, trade, experienceYears } = req.body;
  const normalizedPhone = normalizeTelephone(telephone);
  if (!String(fullName || '').trim() || normalizedPhone.length < 8 || String(password || '').length < 8) {
    return res.status(400).json({ message: 'Nom, téléphone valide et mot de passe (8 caractères minimum) requis.' });
  }
  if (!['mo', 'entrepreneur', 'technicien'].includes(role)) {
    return res.status(400).json({ message: 'Profil invalide.' });
  }
  if (role === 'entrepreneur' && (!String(companyName || '').trim() || !String(rccm || '').trim())) {
    return res.status(400).json({ message: 'Entreprise et RCCM sont obligatoires.' });
  }
  if (role === 'technicien' && !String(trade || '').trim()) {
    return res.status(400).json({ message: 'Le métier est obligatoire.' });
  }

  const passwordHash = await bcrypt.hash(password, 12);
  try {
    const [result] = await pool.execute(
      `INSERT INTO users (full_name, telephone, password_hash, role, city, company_name, rccm, trade, experience_years)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [String(fullName).trim(), normalizedPhone, passwordHash, role, city || null,
        role === 'entrepreneur' ? String(companyName).trim() : null,
        role === 'entrepreneur' ? String(rccm).trim().toUpperCase() : null,
        role === 'technicien' ? String(trade).trim() : null,
        role === 'technicien' ? Number(experienceYears || 0) : null],
    );
    const [rows] = await pool.execute('SELECT * FROM users WHERE id = ?', [result.insertId]);
    const user = safeUser(rows[0]);
    res.status(201).json({ token: makeToken(rows[0]), user });
  } catch (error) {
    if (error.code === 'ER_DUP_ENTRY') return res.status(409).json({ message: 'Ce téléphone ou ce RCCM est déjà associé à un compte.' });
    throw error;
  }
}));

app.post('/api/auth/login', asyncRoute(async (req, res) => {
  const telephone = normalizeTelephone(req.body.telephone);
  const [rows] = await pool.execute('SELECT * FROM users WHERE telephone = ? LIMIT 1', [telephone]);
  const user = rows[0];
  if (!user || !(await bcrypt.compare(String(req.body.password || ''), user.password_hash))) {
    return res.status(401).json({ message: 'Téléphone ou mot de passe incorrect.' });
  }
  res.json({ token: makeToken(user), user: safeUser(user) });
}));

app.get('/api/auth/me', requireAuth, asyncRoute(async (req, res) => {
  const [rows] = await pool.execute('SELECT * FROM users WHERE id = ?', [req.user.id]);
  if (!rows[0]) return res.status(404).json({ message: 'Compte introuvable.' });
  res.json({ user: safeUser(rows[0]) });
}));

app.get('/api/professionals', requireAuth, asyncRoute(async (req, res) => {
  const [rows] = await pool.execute(
    `SELECT u.id, u.full_name, u.role, u.city, u.company_name, u.trade,
            u.experience_years,
            CASE
              WHEN u.role = 'entrepreneur' THEN
                (SELECT COUNT(*) FROM projects p WHERE p.entrepreneur_id = u.id)
              WHEN u.role = 'mo' THEN
                (SELECT COUNT(*) FROM projects p WHERE p.owner_id = u.id)
              ELSE
                (SELECT COUNT(*) FROM project_access_requests a
                 WHERE a.user_id = u.id AND a.requested_role = 'technicien'
                   AND a.status = 'approved')
            END AS project_count,
            (SELECT AVG(pr.rating) FROM project_reviews pr
             JOIN projects p ON p.id = pr.project_id
             WHERE p.entrepreneur_id = u.id OR p.owner_id = u.id) AS average_rating,
            CASE WHEN u.role = 'entrepreneur' THEN
              (SELECT COUNT(DISTINCT a.user_id)
               FROM projects p JOIN project_access_requests a ON a.project_id = p.id
               WHERE p.entrepreneur_id = u.id AND a.requested_role = 'technicien'
                 AND a.status = 'approved')
            ELSE 0 END AS employee_count
     FROM users u
     WHERE u.id <> ?
     ORDER BY u.role, u.full_name`,
    [req.user.id],
  );
  res.json({ professionals: rows.map((row) => ({
    id: String(row.id),
    fullName: row.full_name,
    role: row.role,
    city: row.city,
    companyName: row.company_name,
    trade: row.trade,
    experienceYears: row.experience_years,
    projectCount: Number(row.project_count),
    averageRating: row.average_rating === null ? null : Number(row.average_rating),
    employeeCount: Number(row.employee_count),
  })) });
}));

app.get('/api/work-requests', requireAuth, asyncRoute(async (req, res) => {
  const [rows] = await pool.execute(
    `SELECT r.id, r.sender_id, r.recipient_id, r.project_name, r.message,
            r.status, r.created_at, r.updated_at,
            s.full_name AS sender_name, s.role AS sender_role,
            t.full_name AS recipient_name, t.role AS recipient_role
     FROM work_requests r
     JOIN users s ON s.id = r.sender_id
     JOIN users t ON t.id = r.recipient_id
     WHERE r.sender_id = ? OR r.recipient_id = ?
     ORDER BY r.created_at DESC`,
    [req.user.id, req.user.id],
  );
  const requests = rows.map((row) => ({
    id: String(row.id),
    senderId: String(row.sender_id),
    senderName: row.sender_name,
    senderRole: row.sender_role,
    recipientId: String(row.recipient_id),
    recipientName: row.recipient_name,
    recipientRole: row.recipient_role,
    projectName: row.project_name,
    message: row.message,
    status: row.status,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  }));
  res.json({
    incoming: requests.filter((request) => request.recipientId === String(req.user.id)),
    outgoing: requests.filter((request) => request.senderId === String(req.user.id)),
  });
}));

app.post('/api/work-requests', requireAuth, asyncRoute(async (req, res) => {
  const recipientId = String(req.body.recipientId || '').trim();
  const projectName = String(req.body.projectName || '').trim();
  const message = String(req.body.message || '').trim();
  if (!/^\d+$/.test(recipientId) || recipientId === String(req.user.id)) {
    return res.status(400).json({ message: 'Destinataire invalide.' });
  }
  if (projectName.length < 3 || projectName.length > 180) {
    return res.status(400).json({ message: 'Le nom du travail doit contenir entre 3 et 180 caractères.' });
  }
  if (message.length > 2000) {
    return res.status(400).json({ message: 'Le message ne peut pas dépasser 2 000 caractères.' });
  }
  const [recipients] = await pool.execute(
    'SELECT id FROM users WHERE id = ? LIMIT 1',
    [recipientId],
  );
  if (!recipients.length) {
    return res.status(404).json({ message: 'Cet intervenant est introuvable.' });
  }
  const [pending] = await pool.execute(
    `SELECT id FROM work_requests
     WHERE sender_id = ? AND recipient_id = ? AND status = 'pending' LIMIT 1`,
    [req.user.id, recipientId],
  );
  if (pending.length) {
    return res.status(409).json({ message: 'Une demande est déjà en attente pour cet intervenant.' });
  }
  const [result] = await pool.execute(
    `INSERT INTO work_requests (sender_id, recipient_id, project_name, message)
     VALUES (?, ?, ?, ?)`,
    [req.user.id, recipientId, projectName, message || null],
  );
  res.status(201).json({
    message: 'Votre demande de travail a été envoyée.',
    requestId: String(result.insertId),
  });
}));

app.patch('/api/work-requests/:id', requireAuth, asyncRoute(async (req, res) => {
  const status = req.body.status;
  if (!['accepted', 'rejected'].includes(status)) {
    return res.status(400).json({ message: 'Réponse invalide.' });
  }
  const [result] = await pool.execute(
    `UPDATE work_requests SET status = ?
     WHERE id = ? AND recipient_id = ? AND status = 'pending'`,
    [status, req.params.id, req.user.id],
  );
  if (!result.affectedRows) {
    return res.status(404).json({ message: 'Demande introuvable ou déjà traitée.' });
  }
  res.json({
    message: status === 'accepted'
      ? 'Demande acceptée. Vous pouvez maintenant organiser le travail.'
      : 'Demande refusée.',
  });
}));

app.post('/api/uploads/project-image', requireAuth, imageUpload.single('image'), asyncRoute(async (req, res) => {
  if (!process.env.BLOB_READ_WRITE_TOKEN) {
    return res.status(503).json({ message: 'Le stockage d’images Vercel n’est pas configuré.' });
  }
  const projectId = String(req.body.projectId || '').trim();
  const file = req.file;
  if (!projectId || !file) {
    return res.status(400).json({ message: 'Un chantier et une image sont requis.' });
  }
  const signature = file.buffer;
  let contentType;
  let extension;
  if (signature.subarray(0, 3).equals(Buffer.from([0xff, 0xd8, 0xff]))) {
    contentType = 'image/jpeg';
    extension = 'jpg';
  } else if (signature.subarray(0, 8).equals(Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]))) {
    contentType = 'image/png';
    extension = 'png';
  } else if (
    signature.toString('ascii', 0, 4) === 'RIFF' &&
    signature.toString('ascii', 8, 12) === 'WEBP'
  ) {
    contentType = 'image/webp';
    extension = 'webp';
  } else {
    return res.status(400).json({ message: 'Format image non pris en charge (JPEG, PNG ou WebP).' });
  }
  const [allowed] = await pool.execute(
    `SELECT p.id FROM projects p LEFT JOIN project_access_requests a ON a.project_id = p.id
     WHERE p.id = ? AND (p.entrepreneur_id = ? OR
       (a.user_id = ? AND a.requested_role = 'technicien' AND a.status = 'approved')) LIMIT 1`,
    [projectId, req.user.id, req.user.id],
  );
  if (!allowed.length) {
    return res.status(403).json({ message: 'Vous ne pouvez pas publier d’image sur ce chantier.' });
  }
  const blob = await put(
    `project-journal/${projectId}/${randomUUID()}.${extension}`,
    file.buffer,
    { access: 'public', contentType },
  );
  res.status(201).json({ url: blob.url });
}));

app.get('/api/projects', requireAuth, asyncRoute(async (req, res) => {
  let sql = `SELECT p.*, e.full_name AS entrepreneur_name, e.company_name,
                    o.full_name AS owner_name
             FROM projects p JOIN users e ON e.id = p.entrepreneur_id
             LEFT JOIN users o ON o.id = p.owner_id`;
  let params = [];
  if (req.user.role === 'entrepreneur') {
    sql += ' WHERE p.entrepreneur_id = ?'; params = [req.user.id];
  } else if (req.user.role === 'mo') {
    sql += ' WHERE p.owner_id = ?'; params = [req.user.id];
  } else {
    sql += ` JOIN project_access_requests a ON a.project_id = p.id
             WHERE a.user_id = ? AND a.requested_role = 'technicien' AND a.status = 'approved'`;
    params = [req.user.id];
  }
  sql += ' ORDER BY p.created_at DESC';
  const [rows] = await pool.execute(sql, params);
  res.json({ projects: rows.map(projectDto) });
}));

function projectDto(row) {
  return {
    id: String(row.id), code: row.code, name: row.name, description: row.description,
    location: row.location, progress: row.progress, status: row.status,
    entrepreneurId: String(row.entrepreneur_id), entrepreneurName: row.entrepreneur_name,
    companyName: row.company_name, ownerId: row.owner_id ? String(row.owner_id) : null,
    ownerName: row.owner_name, createdAt: row.created_at,
  };
}

app.post('/api/projects', requireAuth, requireRole('entrepreneur'), asyncRoute(async (req, res) => {
  const name = String(req.body.name || '').trim();
  if (name.length < 3) return res.status(400).json({ message: 'Le nom du chantier doit contenir au moins 3 caractères.' });
  let code;
  for (let attempts = 0; attempts < 8; attempts += 1) {
    code = `BTP-${randomBytes(2).toString('hex').toUpperCase()}`;
    const [found] = await pool.execute('SELECT id FROM projects WHERE code = ?', [code]);
    if (!found.length) break;
    code = null;
  }
  if (!code) return res.status(503).json({ message: 'Impossible de générer un code, réessayez.' });
  const [result] = await pool.execute(
    'INSERT INTO projects (code, name, description, location, entrepreneur_id) VALUES (?, ?, ?, ?, ?)',
    [code, name, req.body.description || null, req.body.location || null, req.user.id],
  );
  const [rows] = await pool.execute(
    `SELECT p.*, u.full_name AS entrepreneur_name, u.company_name FROM projects p
     JOIN users u ON u.id = p.entrepreneur_id WHERE p.id = ?`, [result.insertId],
  );
  res.status(201).json({ project: projectDto(rows[0]) });
}));

app.post('/api/projects/join', requireAuth, requireRole('mo', 'technicien'), asyncRoute(async (req, res) => {
  const code = String(req.body.code || '').trim().toUpperCase();
  const [projects] = await pool.execute('SELECT * FROM projects WHERE code = ? LIMIT 1', [code]);
  if (!projects[0]) return res.status(404).json({ message: 'Aucun chantier ne correspond à ce code.' });
  const project = projects[0];
  if (req.user.role === 'mo' && project.owner_id) {
    return res.status(409).json({ message: 'Ce chantier est déjà associé à un maître d’ouvrage.' });
  }
  try {
    await pool.execute(
      `INSERT INTO project_access_requests (project_id, user_id, requested_role)
       VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE status = IF(status = 'rejected', 'pending', status), created_at = CURRENT_TIMESTAMP`,
      [project.id, req.user.id, req.user.role],
    );
  } catch (error) { throw error; }
  res.status(201).json({ message: 'Demande envoyée. Elle sera visible après validation par l’entrepreneur.' });
}));

app.get('/api/projects/requests', requireAuth, requireRole('entrepreneur'), asyncRoute(async (req, res) => {
  const [rows] = await pool.execute(
    `SELECT a.id, a.requested_role, a.status, a.created_at, u.id AS user_id,
            u.full_name, u.telephone, u.trade, u.experience_years, p.id AS project_id,
            p.code, p.name AS project_name
     FROM project_access_requests a JOIN users u ON u.id = a.user_id
     JOIN projects p ON p.id = a.project_id
     WHERE p.entrepreneur_id = ? AND a.status = 'pending' ORDER BY a.created_at DESC`,
    [req.user.id],
  );
  res.json({ requests: rows.map((row) => ({
    id: String(row.id), userId: String(row.user_id), name: row.full_name,
    telephone: row.telephone, trade: row.trade, experienceYears: row.experience_years,
    role: row.requested_role, projectId: String(row.project_id), code: row.code,
    projectName: row.project_name, createdAt: row.created_at,
  })) });
}));

app.patch('/api/projects/requests/:id', requireAuth, requireRole('entrepreneur'), asyncRoute(async (req, res) => {
  const status = req.body.status;
  if (!['approved', 'rejected'].includes(status)) return res.status(400).json({ message: 'Décision invalide.' });
  const connection = await pool.getConnection();
  try {
    await connection.beginTransaction();
    const [rows] = await connection.execute(
      `SELECT a.*, p.entrepreneur_id, p.owner_id FROM project_access_requests a
       JOIN projects p ON p.id = a.project_id WHERE a.id = ? FOR UPDATE`, [req.params.id],
    );
    const request = rows[0];
    if (!request || String(request.entrepreneur_id) !== String(req.user.id) || request.status !== 'pending') {
      await connection.rollback();
      return res.status(404).json({ message: 'Demande introuvable ou déjà traitée.' });
    }
    if (status === 'approved' && request.requested_role === 'mo' && request.owner_id) {
      await connection.rollback();
      return res.status(409).json({ message: 'Un maître d’ouvrage est déjà associé à ce chantier.' });
    }
    if (status === 'approved' && request.requested_role === 'mo') {
      await connection.execute('UPDATE projects SET owner_id = ? WHERE id = ?', [request.user_id, request.project_id]);
    }
    await connection.execute('UPDATE project_access_requests SET status = ? WHERE id = ?', [status, request.id]);
    await connection.commit();
    res.json({ message: status === 'approved' ? 'Demande acceptée.' : 'Demande refusée.' });
  } catch (error) {
    await connection.rollback(); throw error;
  } finally { connection.release(); }
}));

app.get('/api/projects/:id/journal', requireAuth, asyncRoute(async (req, res) => {
  const [allowed] = await pool.execute(
    `SELECT p.id FROM projects p LEFT JOIN project_access_requests a ON a.project_id = p.id
     WHERE p.id = ? AND (p.entrepreneur_id = ? OR p.owner_id = ? OR
       (a.user_id = ? AND a.requested_role = 'technicien' AND a.status = 'approved')) LIMIT 1`,
    [req.params.id, req.user.id, req.user.id, req.user.id],
  );
  if (!allowed.length) return res.status(403).json({ message: 'Vous n’avez pas accès à ce chantier.' });
  const [rows] = await pool.execute(
    `SELECT j.*, u.full_name AS author_name FROM journal_entries j
     JOIN users u ON u.id = j.author_id WHERE j.project_id = ? ORDER BY j.created_at DESC`,
    [req.params.id],
  );
  res.json({ entries: rows.map((row) => ({
    id: String(row.id), description: row.description, progress: row.progress,
    photoUrl: row.photo_url, authorName: row.author_name, createdAt: row.created_at,
  })) });
}));

app.post('/api/projects/:id/journal', requireAuth, requireRole('entrepreneur', 'technicien'), asyncRoute(async (req, res) => {
  const description = String(req.body.description || '').trim();
  const progress = Number(req.body.progress);
  if (!description || !Number.isInteger(progress) || progress < 0 || progress > 100) {
    return res.status(400).json({ message: 'Description et avancement entre 0 et 100 requis.' });
  }
  const [allowed] = await pool.execute(
    `SELECT p.id FROM projects p LEFT JOIN project_access_requests a ON a.project_id = p.id
     WHERE p.id = ? AND (p.entrepreneur_id = ? OR
       (a.user_id = ? AND a.requested_role = 'technicien' AND a.status = 'approved')) LIMIT 1`,
    [req.params.id, req.user.id, req.user.id],
  );
  if (!allowed.length) return res.status(403).json({ message: 'Vous ne pouvez pas modifier ce chantier.' });
  const connection = await pool.getConnection();
  try {
    await connection.beginTransaction();
    await connection.execute(
      'INSERT INTO journal_entries (project_id, author_id, description, progress, photo_url) VALUES (?, ?, ?, ?, ?)',
      [req.params.id, req.user.id, description, progress, req.body.photoUrl || null],
    );
    await connection.execute('UPDATE projects SET progress = ? WHERE id = ?', [progress, req.params.id]);
    await connection.commit();
    res.status(201).json({ message: 'Mise à jour du chantier enregistrée.' });
  } catch (error) { await connection.rollback(); throw error; }
  finally { connection.release(); }
}));

app.post('/api/projects/:id/reviews', requireAuth, requireRole('mo'), asyncRoute(async (req, res) => {
  const rating = Number(req.body.rating);
  if (!Number.isInteger(rating) || rating < 1 || rating > 5) {
    return res.status(400).json({ message: 'La note doit être comprise entre 1 et 5.' });
  }
  const [projects] = await pool.execute(
    'SELECT owner_id, entrepreneur_id FROM projects WHERE id = ?',
    [req.params.id],
  );
  if (!projects[0] || String(projects[0].owner_id) !== String(req.user.id)) {
    return res.status(403).json({ message: 'Seul le client associé au chantier peut laisser un avis.' });
  }
  if (String(projects[0].entrepreneur_id) !== String(req.body.targetId)) {
    return res.status(400).json({ message: 'Le destinataire de l’avis doit être l’entrepreneur du chantier.' });
  }
  await pool.execute(
    'INSERT INTO reviews (project_id, author_id, target_id, rating, comment) VALUES (?, ?, ?, ?, ?)',
    [req.params.id, req.user.id, req.body.targetId, rating, req.body.comment || null],
  );
  res.status(201).json({ message: 'Merci pour votre avis.' });
}));

app.get('/api/projects/:id/project-reviews', requireAuth, asyncRoute(async (req, res) => {
  const [allowed] = await pool.execute(
    `SELECT p.id FROM projects p LEFT JOIN project_access_requests a ON a.project_id = p.id
     WHERE p.id = ? AND (p.entrepreneur_id = ? OR p.owner_id = ? OR
       (a.user_id = ? AND a.requested_role = 'technicien' AND a.status = 'approved')) LIMIT 1`,
    [req.params.id, req.user.id, req.user.id, req.user.id],
  );
  if (!allowed.length) return res.status(403).json({ message: 'Vous n’avez pas accès à ce chantier.' });
  const [rows] = await pool.execute(
    `SELECT r.id, r.author_id, r.rating, r.comment, r.created_at, u.full_name AS author_name
     FROM project_reviews r JOIN users u ON u.id = r.author_id
     WHERE r.project_id = ? ORDER BY r.created_at DESC`,
    [req.params.id],
  );
  const ratings = rows.map((row) => ({
    id: String(row.id),
    authorId: String(row.author_id),
    authorName: row.author_name,
    rating: row.rating,
    comment: row.comment,
    createdAt: row.created_at,
  }));
  res.json({
    reviews: ratings,
    average: ratings.length
      ? ratings.reduce((total, review) => total + review.rating, 0) / ratings.length
      : null,
    myReview: ratings.find((review) => review.authorId === String(req.user.id)) || null,
  });
}));

app.post('/api/projects/:id/project-reviews', requireAuth, asyncRoute(async (req, res) => {
  const rating = Number(req.body.rating);
  const comment = String(req.body.comment || '').trim();
  if (!Number.isInteger(rating) || rating < 1 || rating > 5) {
    return res.status(400).json({ message: 'La note doit être comprise entre 1 et 5.' });
  }
  if (comment.length > 2000) {
    return res.status(400).json({ message: 'Le commentaire ne peut pas dépasser 2 000 caractères.' });
  }
  const [allowed] = await pool.execute(
    `SELECT p.id FROM projects p LEFT JOIN project_access_requests a ON a.project_id = p.id
     WHERE p.id = ? AND (p.entrepreneur_id = ? OR p.owner_id = ? OR
       (a.user_id = ? AND a.requested_role = 'technicien' AND a.status = 'approved')) LIMIT 1`,
    [req.params.id, req.user.id, req.user.id, req.user.id],
  );
  if (!allowed.length) return res.status(403).json({ message: 'Vous devez participer à ce chantier pour le noter.' });
  try {
    await pool.execute(
      'INSERT INTO project_reviews (project_id, author_id, rating, comment) VALUES (?, ?, ?, ?)',
      [req.params.id, req.user.id, rating, comment || null],
    );
  } catch (error) {
    if (error.code === 'ER_DUP_ENTRY') {
      return res.status(409).json({ message: 'Vous avez déjà noté ce chantier.' });
    }
    throw error;
  }
  res.status(201).json({ message: 'Merci pour votre avis.' });
}));

app.use((error, _req, res, _next) => {
  console.error(error);
  if (error instanceof multer.MulterError) {
    const status = error.code === 'LIMIT_FILE_SIZE' ? 413 : 400;
    return res.status(status).json({
      message: status === 413
        ? 'L’image dépasse la taille maximale de 8 Mo.'
        : 'La requête d’image est invalide.',
    });
  }
  res.status(500).json({ message: 'Erreur interne du serveur.' });
});

app.listen(port, () => console.log(`BTP API tourne sur le port ${port}`));
